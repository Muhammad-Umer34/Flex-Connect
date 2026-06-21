const fs = require("fs");
const xlsx = require("xlsx");

const workbook = xlsx.readFileSync("../uploaded_timetable.xlsx");
const sheetName = workbook.SheetNames.includes("Combined TT") ? "Combined TT" : workbook.SheetNames[0];
const sheet = workbook.Sheets[sheetName];
const range = xlsx.utils.decode_range(sheet['!ref']);

let currentDay = "Monday";
for (let r = range.s.r; r <= range.e.r; r++) {
  const dayCell = sheet[xlsx.utils.encode_cell({ r, c: 0 })];
  if (dayCell && dayCell.v) {
    const val = dayCell.v.toString().trim().toLowerCase();
    if (val.startsWith("mon")) currentDay = "Monday";
    else if (val.startsWith("tue")) curr
    entDay = "Tuesday";
    else if (val.startsWith("wed")) currentDay = "Wednesday";
    else if (val.startsWith("thu")) currentDay = "Thursday";
    else if (val.startsWith("fri")) currentDay = "Friday";
    else if (val.startsWith("sat")) currentDay = "Saturday";
    else if (val.startsWith("sun")) currentDay = "Sunday";
  }

  const roomCell = sheet[xlsx.utils.encode_cell({ r, c: 1 })];
  const room = roomCell && roomCell.v ? roomCell.v.toString().trim() : "";

  for (let c = range.s.c + 2; c <= range.e.c; c++) {
    const cell = sheet[xlsx.utils.encode_cell({ r, c })];
    if (cell && cell.v) {
      const val = cell.v.toString();
      if (val.includes("AI Lab") || val.includes("Lab-18")) {
        let cStart = c;
        let cEnd = c;
        if (sheet['!merges']) {
          const merge = sheet['!merges'].find(m => r >= m.s.r && r <= m.e.r && c >= m.s.c && c <= m.e.c);
          if (merge) {
            cStart = merge.s.c;
            cEnd = merge.e.c;
          }
        }
        console.log(`Day: ${currentDay}, Row: ${r}, Col: ${c}, Val: "${val}", room: "${room}", cStart: ${cStart}, cEnd: ${cEnd}`);
      }
    }
  }
}
