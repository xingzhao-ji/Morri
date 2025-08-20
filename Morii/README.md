Our source code was submitted late because we didn't submit the .git folder in our code. However, the spec didn't particularly mention this except for the relatively vague statement "submit a compressed tarball of your git repository" so I downloaded the files from GitHub. I hope you can be understanding in this.

This tarball contains the source code and documentation for our project, with separate backend (Express.js) and frontend (Swift) components.

By the time you are reading this, our app would have been approved for App Store approval. In which you can find it on the iOS App Store called “Morii - Moments That Stay.”

OUR APP IS ON THE APP STORE NOW!! https://apps.apple.com/app/id6746750544 

Some key points: You don’t actually have to run the backend to use our app, only the frontend setup is necessary. I currently have it configured to use our backend hosted on Heroku rather than localhost. Of course, you can also just try running our app by downloading from the App Store. 

## Directory Structure
- `backend/`: Contains the Express.js backend source code (from the `main` branch).
- `frontend/`: Contains the Swift frontend source code (from the `frontend` branch).
- `.env` files: Included in both backend and frontend directories for local deployment. These are not committed to Git (per `.gitignore\)). The frontend environment files are the Config.swift and GoogleService.plist files.

## Setup Instructions

### Backend (Express.js)
1. Navigate to the `backend` directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Ensure the `.env` file is configured with the correct environment variables (e.g., `DATABASE_URL`, `API_KEY`).
4. Start the backend server:
   ```bash
   npm run dev
   ```

### Frontend (Swift)
1. Navigate to the `frontend` directory:
   ```bash
   cd frontend
   ```
2. Open the Xcode project (`YourProject.xcodeproj`) in Xcode.
4. Build and run the project in Xcode:
   ```bash
   xcodebuild
   ```
   Or use the Xcode UI to build and run. Hit the play button on the top left. This should work as everything should download automatically, however, if it says you are missing a package, you may need to install firebase. Go to the top left of File -> Add Package Dependency and copy this url: https://github.com/firebase/firebase-ios-sdk.git

## Notes
- Generated files (e.g., `node_modules`, Xcode build artifacts) are excluded per the instructions and listed in `.gitignore\).
- Ensure all dependencies are installed as described above before running the project.
- The `.env` files are included in this tarball for local deployment but should not be committed to the Git repository.

If there are any questions or concerns, please text/call Yang at 408-603-7854 or email at gaoyang1000@gmail.com. 
