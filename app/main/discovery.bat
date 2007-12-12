@echo off
@setlocal

set DISCOVERY_HOME=%~dp0%

cd "%DISCOVERY_HOME%"
ruby %DISCOVERY_HOME%\lib\discovery.rb --progress 100 --human-results readable_scanresults.txt %1 %2 %3 %4 %5 %6

