A good way to see possible unique strings in a binary is to run this on a linux box:

strings httpd.exe

It will work to dig out ascii text strings from even a windows .exe file if you run it
on linux:

strings httpd.exe | grep -i "2.2.4"
D:\asf-build\build-2.2.4\Release\httpd.pdb

