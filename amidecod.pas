program amideco_def;

uses
  spr2_ein;

begin
  sprachtabellenkopf(
                    +'EN'
                    +'DE'
                    +''
                    +'');

  sprach_eintrag04('datei_ist_zu_lang',
                   'File is to large! ',
                   'Die angegebene Datei ist zu lang! ',
                   '',
                   '');

  sprach_eintrag04('kann_quellsegment_nicht_finden',
                   'Can not find source segment!',
                   'Kann das Qellsegment nicht finden!',
                   '',
                   '');

  sprach_eintrag04('datei_ist_kein_amibios',
                   'This file is not an AMI-BIOS?',
                   'Diese Datei ist kein AMI-BIOS?',
                   '',
                   '');

  sprach_eintrag04('kopfzeile',
                   'FilePos    Length Target     Type                   unpacked  filename'#13#10
                  +'---------  -----  ---------  -------------------    --------  ------------',
                   'Dateipos.  L„nge  Ziel       Typ                    entpackt  Dateiname'#13#10
                  +'---------  -----  ---------  -------------------    --------  ------------',
                   '',
                   '');

  sprach_eintrag04('nicht_genug_speicher_im_ersten_mb',
                   'Not enough memory below 1 MB!',
                   'Es ist nicht genug Speicher < 1 MB frei!',
                   '',
                   '');

  sprach_eintrag04('benutzung',
                   'usage: AMIDECO <(first) input file> [<target directory>]',
                   'Benutzung: AMIDECO <(erste) Quelldatei> [<Zielverzeichnis>]',
                   '',
                   '');

  {sprach_eintrag04('unbekannte_version_des_fmup_kopfes',
                   'Unknown version of FMUP-header!',
                   'Unbekannte Version des FMUP-Kopfes!',
                   '',
                   '');}

  sprach_eintrag04('kettenfehler',
                   'Found a error in modules chain list!',
                   'Es ist ein Fehler in der Modulkette aufgetreten!',
                   '',
                   '');

  sprach_eintrag04('entpackfehler',
                   'Error during decompression!',
                   'Fehler beim Entpacken!',
                   '',
                   '');


{
  sprach_eintrag04('',
                   '',
                   '',
                   '',
                   '');}

  schreibe_sprach_datei('AMIDECO$.001','AMIDECO$.002','sprach_modul','sprach_start','^string');
end.

