@ECHO OFF

call stampdef AmiDeco.def

rem � Sprache
call pasvp AmiDecod %tmp%\ @AmiDeco.cfg
%tmp%\AmiDecod.exe
del %tmp%\AmiDecod.exe

rem � DPMI32
call pasvpdsp AmiDeco AmiDeco.vk\ @AmiDeco.cfg
copy AmiDeco.vk\AmiDeco.exe AmiDeco.vk\AmiDeco.com
call copywdx AmiDeco.vk\ @AmiDeco.cfg

rem � W32
call pasvpw AmiDeco AmiDeco.vk\ @AmiDeco.cfg
copy AmiDeco.vk\AmiDeco.exe AmiDeco.vk\AmiDecoW.exe

rem � Linux
call pasvpl AmiDeco AmiDeco.vk\ @AmiDeco.cfg
call upx AmiDeco.vk\AmiDeco

rem � OS/2
call pasvpo AmiDeco AmiDeco.vk\ @AmiDeco.cfg

rem rem � Rest
rem call a86com amitrace AmiDeco.vk\

call ..\genvk AmiDeco

cd AmiDeco.vk
call genpgp
cd ..

if [%USER%]==[Veit] copy AmiDeco.vk\amideco.exe D:\extra\amideco.exe
if [%USER%]==[Veit] copy AmiDeco.vk\amideco.com C:\extra\amideco.exe