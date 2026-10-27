# Attendance System - React Frontend (Phase 1)

React + Vite frontend for all roles: Student, Teacher, Coordinator, Accountant, HOD and Admin.
One login page for everyone. The user never chooses a role: the role comes from the account.

**Phase 1 uses demo data**, so the app runs without the backend or MySQL.

## Run it in VS Code
1. Install **Node.js 18 or newer** (nodejs.org, choose LTS). Check with `node -v`.
2. VS Code > File > Open Folder > select `attendance-frontend`.
3. Open the terminal (Ctrl + `) and run:
   ```
   npm install
   npm run dev
   ```
4. Open the address shown (normally http://localhost:5173). The page also works on a phone on the same Wi-Fi
   if you run `npm run dev -- --host` and open `http://<your-PC-IP>:5173`.

## Demo accounts (demo mode only)
| Role | ID | Password |
|---|---|---|
| Student | STU2024001 | student123 |
| Teacher | EMP1001 | teacher123 |
| Coordinator | EMP2001 | coord123 |
| Accountant | EMP3001 | account123 |
| HOD | EMP4001 | hod12345 |
| Admin | ADMIN01 | admin123 |

Emails such as `ayush.singh@college.edu` also work. The login page lists these with one-click fill.

## What to try
- **Teacher > Mark Attendance:** save once, then try again. Duplicates are blocked. Press *Edit* to correct it
  (an audit entry is stored). Records older than 7 days are locked (needs coordinator/HOD approval).
- **Student > Attendance Shortage:** shows classes needed to reach 75%.
- **Any table:** search, filter, *Export CSV*, *Print / PDF*.
- **Coordinator / HOD > Attendance Corrections / Approvals:** approve or reject requests.
- Resize the window: the sidebar becomes a drawer and tables become cards on mobile.

## Project structure
```
src/
  main.jsx, App.jsx, index.css, config.js
  roleConfig.jsx        <- menu + pages for every role (add new pages here)
  context/AuthContext.jsx
  services/             api.js (login + Axios + token), session.js, attendanceStore.js (Phase 1 only)
  data/mockData.js      <- all demo data (replace with API calls in Phase 4)
  components/           Layout, Navbar, Sidebar, ProtectedRoute, StatCard, DataPage, FormPage, ...
  pages/                Login, Profile, student/, teacher/, coordinator/, accountant/, hod/, admin/
```

## Connecting to the Spring Boot backend (Phase 4)
1. Copy `.env.example` to `.env` and set `VITE_USE_MOCK=false`. Restart `npm run dev`.
2. In development, `/api/...` requests are forwarded to `http://localhost:8080` (see `vite.config.js`).
3. Login expects `POST /api/auth/login` with `{ "username": "...", "password": "..." }` and a response like:
   ```json
   { "token": "eyJ...", "userId": 101, "name": "Ayush Singh", "role": "STUDENT", "department": "BCA" }
   ```
   Role values: `STUDENT, TEACHER, COORDINATOR, ACCOUNTANT, HOD, ADMIN` (a `ROLE_` prefix is removed automatically).
4. The JWT is sent as `Authorization: Bearer <token>` on every request. A `401` logs the user out.
5. Planned endpoints: `GET /api/student/attendance`, `GET /api/teacher/classes`, `POST /api/teacher/attendance`,
   `GET /api/coordinator/reports`, `GET /api/accountant/fees`, `GET /api/hod/attendance-summary`.

## Security notes
- Hiding pages in React is **not** security. The backend must check identity, role and data access on every API call
  (e.g. a student may only read their own attendance; an accountant must not edit attendance).
- Demo passwords are visible inside this Phase 1 build. **Do not deploy it publicly.**
- The token is kept in `localStorage` for simplicity. For production consider httpOnly cookies.
- Duplicate attendance must also be blocked in the database (UNIQUE key on student + subject + date).

## Notes
- The logo is `public/logo.svg`. Replace it with your college logo and set `COLLEGE_NAME` in `src/config.js`.
- Minimum attendance (75%) and the edit window (7 days) are set in `src/config.js`.
