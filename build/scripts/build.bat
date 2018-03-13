@echo off
mkdir .\documentation > nul 2>&1
mkdir .\documentation\html > nul 2>&1
mkdir .\documentation\links > nul 2>&1
mkdir .\build > nul 2>&1
mkdir .\build\assemblies > nul 2>&1
mkdir .\build\executables > nul 2>&1
mkdir .\build\interfaces > nul 2>&1
mkdir .\build\libraries > nul 2>&1
mkdir .\build\logs > nul 2>&1
mkdir .\build\maps > nul 2>&1
mkdir .\build\objects > nul 2>&1
mkdir .\build\scripts > nul 2>&1

set version="1.0.4"

echo|set /p="Building the CSPRNG Library (static)... "
dmd ^
 .\source\macros.ddoc ^
 .\source\csprng\system.d ^
 -Dd.\documentation\html\ ^
 -Hd.\build\interfaces ^
 -op ^
 -of.\build\libraries\csprng-%version%.lib ^
 -Xf.\documentation\csprng-%version%.json ^
 -lib ^
 -O ^
 -release ^
 -d
echo Done.

echo|set /p="Building the CSPRNG Library (shared / dynamic)... "
dmd ^
 .\source\csprng\system.d ^
 -of.\build\libraries\csprng-%version%.dll ^
 -lib ^
 -shared ^
 -O ^
 -inline ^
 -release ^
 -d
echo Done.

echo|set /p="Building the CSPRNG Command-Line Tool, get-cryptobytes... "
dmd ^
 .\source\tools\get_cryptobytes.d ^
 -I.\build\interfaces\source ^
 .\build\libraries\csprng-%version%.lib ^
 -of.\build\executables\get-cryptobytes ^
 -inline ^
 -release ^
 -O ^
 -d
echo Done.