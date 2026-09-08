require("dotenv").config();
const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const { chromium } = require("playwright");
const multer = require("multer");
const xlsx = require("xlsx");

const app = express();
const upload = multer({ storage: multer.memoryStorage() });
const loginSessions = new Map();

app.use(cors({
  origin: "*"
}));

app.use(express.json());

// Test route
app.get("/", (req, res) => {
  res.send("Flex Connect API Running 🚀");
});

// API test route
app.get("/api/test", (req, res) => {
  res.json({
    success: true,
    message: "Backend connected successfully"
  });
});

// App Update check route
app.get("/api/app-update", (req, res) => {
  const currentVersion = req.query.version || "1.0.0";
  const latestVersion = process.env.LATEST_APP_VERSION || "1.0.0";
  const downloadUrl = process.env.APP_UPDATE_URL || "";
  const critical = process.env.APP_UPDATE_CRITICAL === "true";
  const releaseNotes = process.env.APP_RELEASE_NOTES || "";

  // Perform version comparison
  const hasUpdate = isVersionNewer(currentVersion, latestVersion);

  res.json({
    success: true,
    updateAvailable: hasUpdate,
    latestVersion,
    downloadUrl,
    critical,
    releaseNotes
  });
});

// Helper function to compare semver versions (e.g., "1.0.0" vs "1.0.1")
function isVersionNewer(current, latest) {
  try {
    const parse = (v) => v.split(".").map(x => parseInt(x) || 0);
    const cParts = parse(current);
    const lParts = parse(latest);
    
    for (let i = 0; i < Math.max(cParts.length, lParts.length); i++) {
      const c = cParts[i] || 0;
      const l = lParts[i] || 0;
      if (l > c) return true;
      if (c > l) return false;
    }
  } catch (e) {
    return current !== latest;
  }
  return false;
}


async function handleUniversityLogin(req, res) {
  const { rollNumber, password } = req.body || {};

  if (!rollNumber || !password) {
    return res.status(400).json({
      success: false,
      message: "rollNumber and password are required"
    });
  }

  const sessionId = crypto.randomUUID();
  const session = {
    status: "starting",
    message: "Opening Flex Student login page..."
  };

  loginSessions.set(sessionId, session);

  try {
    const browser = await chromium.launch({
      headless: process.env.PLAYWRIGHT_HEADLESS !== "false"
    });

    const page = await browser.newPage();
    session.browser = browser;
    session.page = page;
    session.status = "captcha_required";
    session.message = "Username and password are filled. Complete the verification challenge below those fields in the opened browser window, then submit the form there.";

    await page.goto("https://flexstudent.nu.edu.pk/Login", {
      waitUntil: "domcontentloaded"
    });

    const rollNumberField = page.locator('input[name="username"]');
    const passwordField = page.locator('input#pass[name="password"]');

    await rollNumberField.fill(rollNumber);
    await passwordField.fill(password);

    return res.json({
      success: true,
      sessionId,
      status: session.status,
      message: session.message
    });
  } catch (error) {
    loginSessions.delete(sessionId);

    return res.status(500).json({
      success: false,
      message: error.message || "Failed to start university login"
    });
  }
}

app.post("/api/university/login", handleUniversityLogin);
app.post("/api", handleUniversityLogin);

app.get("/api/university/login/:sessionId", (req, res) => {
  const session = loginSessions.get(req.params.sessionId);

  if (!session) {
    return res.status(404).json({
      success: false,
      message: "Session not found"
    });
  }

  return res.json({
    success: true,
    status: session.status,
    message: session.message
  });
});

// Timetable Excel Parser Helper
function parseTimetableExcel(fileBuffer, degreeLevel) {
  const xlsx = require("xlsx");
  const workbook = xlsx.read(fileBuffer, { type: "buffer" });
  const schedule = [];
  const departmentsSet = new Set();
  const sectionsMap = new Map();
  const seenEvents = new Set();

  const deptMapping = {
    'BCS': 'CS',
    'BSE': 'SE',
    'BAI': 'AI',
    'BDS': 'DS',
    'BSD': 'DS',
    'BCY': 'CY',
    'BBA': 'BA',
    'BFT': 'FT',
    'BS': 'CS',
    'MCS': 'CS',
    'MS': 'MS',
    'PHD': 'PhD'
  };

  const blockTimes = [
    "08:30-10:00",
    "10:00-11:30",
    "11:30-13:00",
    "13:00-14:30",
    "14:30-16:00",
    "16:00-17:30",
    "17:30-19:00",
    "19:00-20:30"
  ];

  // Prioritize parsing Combined TT sheet
  let sheetsToParse = workbook.SheetNames;
  if (workbook.SheetNames.includes("Combined TT")) {
    sheetsToParse = ["Combined TT"];
  }

  for (const sheetName of sheetsToParse) {
    const sheet = workbook.Sheets[sheetName];
    if (!sheet || !sheet['!ref']) continue;

    const range = xlsx.utils.decode_range(sheet['!ref']);
    let currentDay = "Monday";

    for (let r = range.s.r; r <= range.e.r; r++) {
      // 1. Detect Day in Column 0
      const dayCell = sheet[xlsx.utils.encode_cell({ r, c: 0 })];
      if (dayCell && dayCell.v) {
        const val = dayCell.v.toString().trim().toLowerCase();
        if (val.startsWith("mon")) currentDay = "Monday";
        else if (val.startsWith("tue")) currentDay = "Tuesday";
        else if (val.startsWith("wed")) currentDay = "Wednesday";
        else if (val.startsWith("thu")) currentDay = "Thursday";
        else if (val.startsWith("fri")) currentDay = "Friday";
        else if (val.startsWith("sat")) currentDay = "Saturday";
        else if (val.startsWith("sun")) currentDay = "Sunday";
      }

      // 2. Room Name in Column 1
      const roomCell = sheet[xlsx.utils.encode_cell({ r, c: 1 })];
      const room = roomCell && roomCell.v ? roomCell.v.toString().trim() : "";
      if (!room || room === "Room" || room === "Periods" || room === "Days") continue;

      // 3. Scan columns for class cells starting from Column 2
      for (let c = range.s.c + 2; c <= range.e.c; c++) {
        const cell = sheet[xlsx.utils.encode_cell({ r, c })];
        if (!cell || !cell.v) continue;

        const val = cell.v.toString().trim();
        if (val.length < 3) continue; // skip noise/empty cells

        // Check merge ranges to find start and end columns for the cell
        let cStart = c;
        let cEnd = c;
        if (sheet['!merges']) {
          const merge = sheet['!merges'].find(m => r >= m.s.r && r <= m.e.r && c >= m.s.c && c <= m.e.c);
          if (merge) {
            // Only process the cell if we are at the top-left (start) of the merged range
            if (c !== merge.s.c) continue;
            cStart = merge.s.c;
            cEnd = merge.e.c;
          }
        }

        // Match sections like BCS-4D or BDS-2B
        const sectionRegex = /\b(BCS|BSE|BAI|BDS|BSD|BCY|BBA|BFT|MCS|MS|PHD|BS)\s*[-–—]?\s*([0-9])\s*([A-Za-z])\b/gi;
        let match;
        const matches = [];
        while ((match = sectionRegex.exec(val)) !== null) {
          matches.push({
            full: match[0],
            deptPrefix: match[1].toUpperCase(),
            semester: match[2],
            sectionLetter: match[3].toUpperCase()
          });
        }

        if (matches.length === 0) continue;

        // 4. Resolve Time based on start and end column boundaries of the cell
        const startIndex = Math.floor((cStart - 5) / 9);
        const endIndex = Math.floor((cEnd - 5) / 9);
        const startTime = (startIndex >= 0 && startIndex < blockTimes.length)
          ? blockTimes[startIndex].split("-")[0].trim()
          : "08:30";
        const endTime = (endIndex >= 0 && endIndex < blockTimes.length)
          ? blockTimes[endIndex].split("-")[1].trim()
          : "10:00";
        const time = `${startTime}-${endTime}`;

        // 5. Clean up the course name and teacher from the cell value
        let cleanVal = val;
        for (const m of matches) {
          cleanVal = cleanVal.replace(new RegExp(`\\(?\\s*${m.full}\\s*\\)?`, 'gi'), '');
        }
        // Remove empty parens left over (e.g. from "(BCS-4D)" -> "()")
        cleanVal = cleanVal.replace(/\(\s*[,;\s]*\)/g, '');
        // Remove extra spaces
        cleanVal = cleanVal.replace(/\s+/g, ' ').trim();
        // Remove trailing or leading colons/commas
        cleanVal = cleanVal.replace(/^[:,\s]+|[:,\s]+$/g, '').trim();

        let course = cleanVal;
        let teacher = "Staff";

        if (cleanVal.includes(":")) {
          const parts = cleanVal.split(":");
          course = parts[0].trim();
          teacher = parts.slice(1).join(":").trim();
        }

        // Fallbacks if splitting left empty strings
        if (!course) course = "Scheduled Class";
        if (!teacher) teacher = "Staff";

        // 6. Process each section match
        for (const m of matches) {
          const mappedDept = deptMapping[m.deptPrefix] || m.deptPrefix;
          let matchDegree = "bachelors";
          if (["MCS", "MS", "PHD"].includes(m.deptPrefix)) {
            matchDegree = "masters";
          }

          if (matchDegree !== degreeLevel) continue;

          departmentsSet.add(mappedDept);

          const deptSection = `${mappedDept}-${m.semester}${m.sectionLetter}`;
          if (!sectionsMap.has(mappedDept)) {
            sectionsMap.set(mappedDept, new Set());
          }
          sectionsMap.get(mappedDept).add(deptSection);

          // Unique event key for de-duplication
          const eventKey = `${currentDay}|${time}|${room}|${deptSection}|${course}|${teacher}|${matchDegree}`;
          if (seenEvents.has(eventKey)) continue;
          seenEvents.add(eventKey);

          schedule.push({
            day: currentDay,
            time: time,
            room: room,
            section: deptSection,
            originalSection: m.full,
            course: course,
            teacher: teacher,
            degree: matchDegree
          });
        }
      }
    }
  }

  const departments = Array.from(departmentsSet).sort();
  const sections = {};
  for (const [dept, secSet] of sectionsMap.entries()) {
    sections[dept] = Array.from(secSet).sort();
  }

  return {
    departments,
    sections,
    schedule
  };
}

// Endpoint to upload and parse timetable Excel sheet
app.post("/api/timetable/parse", upload.single("excel"), (req, res) => {
  try {
    console.log("\n=================== START TIMETABLE PARSING ===================");
    if (!req.file) {
      console.log("Error: No file uploaded");
      return res.status(400).json({
        success: false,
        message: "No Excel file was uploaded."
      });
    }

    const degree = (req.body.degree || "bachelors").toLowerCase();
    const campus = req.body.campus || "Islamabad";

    console.log(`[Step 1] Received file: ${req.file.originalname} (${req.file.size} bytes)`);
    console.log(`[Step 1] Parameters: Campus = ${campus}, Degree = ${degree}`);

    console.log("[Step 2] Processing Excel sheet blocks...");
    const parsedData = parseTimetableExcel(req.file.buffer, degree);

    console.log("[Step 3] Processing completed successfully!");
    console.log(`Parsed Departments: ${JSON.stringify(parsedData.departments)}`);
    console.log(`Parsed Sections Count: ${Object.keys(parsedData.sections).length}`);
    console.log(`Total Schedule Events Count: ${parsedData.schedule.length}`);
    
    if (parsedData.schedule.length > 0) {
      console.log("Sample Schedule Event [0]:", JSON.stringify(parsedData.schedule[0]));
    }
    console.log("==================== END TIMETABLE PARSING ====================\n");

    return res.json({
      success: true,
      campus,
      degree,
      departments: parsedData.departments,
      sections: parsedData.sections,
      schedule: parsedData.schedule
    });
  } catch (err) {
    console.error("\n*** Timetable parse error:", err);
    console.log("===============================================================\n");
    return res.status(500).json({
      success: false,
      message: err.message || "An error occurred while parsing the Excel file."
    });
  }
});

const nodemailer = require("nodemailer");
const fs = require("fs");
const path = require("path");

app.post("/api/feedback", async (req, res) => {
  const { name, rollNumber, email, category, message } = req.body || {};

  if (!message) {
    return res.status(400).json({
      success: false,
      message: "Feedback message is required."
    });
  }

  const feedbackData = {
    id: crypto.randomUUID(),
    name: name || "Anonymous",
    rollNumber: rollNumber || "N/A",
    email: email || "N/A",
    category: category || "Suggestion",
    message,
    timestamp: new Date().toISOString()
  };

  console.log(`\n=================== RECEIVED FEEDBACK ===================`);
  console.log(`From: ${feedbackData.name} (${feedbackData.rollNumber})`);
  console.log(`Category: ${feedbackData.category}`);
  console.log(`Message: ${feedbackData.message}`);
  console.log(`=========================================================\n`);

  // 1. Save to backup local file so no feedback is ever lost
  try {
    const feedbackFilePath = path.join(__dirname, "feedback.json");
    let feedbackList = [];
    if (fs.existsSync(feedbackFilePath)) {
      const rawData = fs.readFileSync(feedbackFilePath, "utf8");
      feedbackList = JSON.parse(rawData);
    }
    feedbackList.push(feedbackData);
    fs.writeFileSync(feedbackFilePath, JSON.stringify(feedbackList, null, 2), "utf8");
    console.log("Feedback saved successfully to backup local feedback.json");
  } catch (fileErr) {
    console.error("Failed to write to local feedback.json backup:", fileErr);
  }

  // 2. Send email if SMTP credentials are provided
  const smtpHost = process.env.SMTP_HOST;
  const smtpPort = process.env.SMTP_PORT;
  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;

  if (smtpHost && smtpUser && smtpPass) {
    try {
      const isSecure = process.env.SMTP_SECURE === "true" || smtpPort === "465";
      const transporter = nodemailer.createTransport({
        host: smtpHost,
        port: parseInt(smtpPort || "587"),
        secure: isSecure,
        auth: {
          user: smtpUser,
          pass: smtpPass
        }
      });

      const mailOptions = {
        from: `"${feedbackData.name} (Flex Connect)" <${smtpUser}>`,
        to: "flexconnect03@gmail.com",
        replyTo: feedbackData.email !== "N/A" ? feedbackData.email : undefined,
        subject: `[Flex Connect Feedback] ${feedbackData.category} - ${feedbackData.rollNumber}`,
        html: `
          <div style="font-family: Arial, sans-serif; padding: 20px; line-height: 1.6; color: #333;">
            <h2 style="color: #2563EB; border-bottom: 2px solid #2563EB; padding-bottom: 8px;">New Feedback Received</h2>
            <table style="width: 100%; border-collapse: collapse; margin-top: 15px;">
              <tr style="background-color: #f8fafc;">
                <td style="padding: 10px; font-weight: bold; width: 140px;">Student Name:</td>
                <td style="padding: 10px;">${feedbackData.name}</td>
              </tr>
              <tr>
                <td style="padding: 10px; font-weight: bold;">Roll Number:</td>
                <td style="padding: 10px;">${feedbackData.rollNumber}</td>
              </tr>
              <tr style="background-color: #f8fafc;">
                <td style="padding: 10px; font-weight: bold;">Email:</td>
                <td style="padding: 10px;">${feedbackData.email}</td>
              </tr>
              <tr>
                <td style="padding: 10px; font-weight: bold;">Category:</td>
                <td style="padding: 10px;"><span style="background-color: #dbeafe; color: #2563eb; padding: 3px 8px; border-radius: 4px; font-size: 12px; font-weight: bold;">${feedbackData.category.toUpperCase()}</span></td>
              </tr>
              <tr style="background-color: #f8fafc;">
                <td style="padding: 10px; font-weight: bold;">Timestamp:</td>
                <td style="padding: 10px;">${feedbackData.timestamp}</td>
              </tr>
            </table>
            
            <h3 style="margin-top: 25px; color: #1e293b;">Message Content:</h3>
            <div style="background-color: #f1f5f9; padding: 15px; border-radius: 8px; border-left: 4px solid #94a3b8; font-style: italic; white-space: pre-wrap;">${feedbackData.message}</div>
            
            <p style="margin-top: 30px; font-size: 11px; color: #64748b; border-top: 1px solid #e2e8f0; padding-top: 12px;">
              This email was generated automatically by the Flex Connect feedback module.
            </p>
          </div>
        `
      };

      await transporter.sendMail(mailOptions);
      console.log(`Email successfully delivered to flexconnect03@gmail.com`);
      
      return res.json({
        success: true,
        message: "Feedback submitted and email sent successfully!"
      });
    } catch (mailErr) {
      console.error("Nodemailer failed to send email:", mailErr);
      return res.json({
        success: true,
        emailSent: false,
        message: "Feedback saved on server, but failed to deliver email: " + mailErr.message
      });
    }
  } else {
    console.log("SMTP environment variables not configured. Skipping email delivery.");
    return res.json({
      success: true,
      emailSent: false,
      message: "Feedback saved locally on server. (SMTP credentials not configured in .env)."
    });
  }
});

const PORT = process.env.PORT || 5000;

process.on("unhandledRejection", (reason) => {
  console.error("Unhandled rejection:", reason);
});

process.on("uncaughtException", (error) => {
  console.error("Uncaught exception:", error);
});

const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

server.on("error", (error) => {
  if (error.code === "EADDRINUSE") {
    console.error(`Port ${PORT} is already in use. Stop the other process or set PORT.`);
  } else {
    console.error("Server error:", error);
  }
  process.exit(1);
});