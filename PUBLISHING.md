# Publish this repository

This directory is ready to be used as a GitHub repository. Directory and file names are ASCII. The largest single file is the released FPGA BIT, below GitHub's 100 MB per-file limit. The project includes measured raw CSVs so others can rerun the MATLAB analysis.

Before making the repository public, the project owners need to select a license for the code and verify that any bundled vendor-generated IP and data can be redistributed under their respective terms. No license is implied by public visibility. Add the chosen `LICENSE` file at the repository root.

After a GitHub repository URL is available, run from this directory with Git configured for the project owner:

```powershell
git init
git add .
git commit -m "Publish FPGA VGA RF response capture project"
git branch -M main
git remote add origin <your-github-repository-url>
git push -u origin main
```

The checked-in XPR can contain build-machine paths; `src/project/scripts/create_project.tcl` is the portable rebuild entry point. The board workflow is documented in `board/README.md`.
