# Publish this repository

This directory is ready to be used as a GitHub repository. Directory and file names are ASCII. The largest single file is the released FPGA BIT, below GitHub's 100 MB per-file limit. The project includes measured raw CSVs so others can rerun the MATLAB analysis.

The project owners have not selected a license. Public visibility does not grant permission to reuse the code, data, or bundled vendor-generated IP. Any future license should be added as a separate decision by the project owners.

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
