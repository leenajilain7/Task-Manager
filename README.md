# TaskFlow

TaskFlow is a native iOS task manager built with SwiftUI. Its dashboard gives a quick view of today's progress, task totals, and upcoming work. Tasks are saved on device with SwiftData.

## Features

- Add tasks with a title, description, due date, category, and priority
- See total, pending, and completed task counts
- Track today's completion progress
- Search task titles and filter by status or category
- Mark tasks complete and keep their state between launches
- Dynamic light and dark appearance
- Import tasks from the app's earlier local storage format

## Technology

- Swift and SwiftUI
- SwiftData local persistence
- SF Symbols
- Minimum deployment: iOS 17

## Architecture

The project separates the SwiftData model, task actions, app entry point, dashboard, reusable components, and migration service. `TaskViewModel` validates input and performs create and completion changes through a `ModelContext`. SwiftUI's `@Query` keeps the dashboard in sync with the local store.

## Project structure

```text
TaskManager/
├── App/                  # App entry point and model container
├── Models/               # SwiftData task model and category/priority types
├── Views/
│   ├── Home/             # Dashboard
│   └── Tasks/            # Task creation form
├── ViewModels/           # Task validation and persistence actions
├── Components/           # Reusable task row
├── Services/             # Legacy data import
├── Utilities/            # Shared helpers
└── Resources/            # App resources
```

## Run locally

1. Open `TaskManager.xcodeproj` in Xcode.
2. Choose the **TaskManager** scheme and an iOS 17+ simulator or device.
3. Build and run.

## Screenshots

Screenshots can be added here after running the app in a simulator.

## Notes

Task data stays on the device. The project currently has no external services or third-party package dependencies.
# Task-Manager
