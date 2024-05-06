Set-ExecutionPolicy RemoteSigned -scope CurrentUser
scoop install stack

# clone the KMonad repository (assuming you have `git` installed)
Set-Location $HOME\Downloads
git clone https://github.com/kmonad/kmonad.git
Set-Location $HOME\Downloads\kmonad
# compile KMonad (this will first download GHC and msys2, it takes a while)
stack build
# install kmonad.exe (copies kmonad.exe to %APPDATA%\local\bin\)
stack install
Copy-Item ..\..\home\config\.config\PowerShell\Scripts\kmonad.ps1 "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"