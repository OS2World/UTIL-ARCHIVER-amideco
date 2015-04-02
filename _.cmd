@ECHO OFF

call stampdef AmiDeco.def

rem þ Sprache
call pasvp AmiDecod %tmp%\ @AmiDeco.cfg
%tmp%\AmiDecod.exe
del %tmp%\AmiDecod.exe

rem þ DPMI32
call pasvpdsp AmiDeco AmiDeco.vk\ @AmiDeco.cfg
copy AmiDeco.vk\AmiDeco.exe AmiDeco.vk\AmiDeco.com
call copywdx AmiDeco.vk\ @AmiDeco.cfg

rem þ W32
call pasvpw AmiDeco AmiDeco.vk\ @AmiDeco.cfg
copy AmiDeco.vk\AmiDeco.exe AmiDeco.vk\AmiDecoW.exe

rem þ Linux
call pasvpl AmiDeco AmiDeco.vk\ @AmiDeco.cfg
call upx AmiDeco.vk\AmiDeco

rem þ OS/2
call pasvpo AmiDeco AmiDeco.vk\ @AmiDeco.cfg

rem rem þ Rest
rem call a86com amitrace AmiDeco.vk\

call ..\genvk AmiDeco

cd AmiDeco.vk
call genpgp
cd ..

if [%USER%]==[Veit] copy AmiDeco.vk\amideco.exe D:\extra\amideco.exe
if [%USER%]==[Veit] copy AmiDeco.vk\amideco.com C:\extra\amideco.exe