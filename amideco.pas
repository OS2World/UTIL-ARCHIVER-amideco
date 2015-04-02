(*$B-,D+,H-,I+,J+,P-,Q-,R-,S-,T-,V+,W-,X+,Z-*)
(*&AlignCode+,AlignData+,AlignRec-,Asm-,Cdecl-,Delphi-,Frame+,G3+*)
(*&LocInfo+,Open32-,Optimise+,OrgName-,SmartLink+,Speed+,Use32+,ZD-*)
(*$M 32768*)

program amibiosdecompressor;

(* 31.03.˙˙09.04.1998   Veit Kannegieser                                   *)
(* 2000.09.14           findet mehr Blîcke                                 *)
(*                      Intel-Module                                       *)
(*                      BP->Virtual Pascal                                 *)
(* 2000.10.02           FSplit, neue Intel-Module                          *)
(* 2000.10.06           énderungen wegen Problemen mit Intel-Teildateien   *)
(* 2000.10.07           lzh5x, OS/2                                        *)
(* 2000.10.15           10001bl0.bio: Fe000 ist FFFFdacc                   *)
(* 2000.12.08           ?                                                  *)
(* 2002.10.12           >128 KB-Blîcke, entpacken von mehr modulo 64 KB    *)
(*                      mix.rom wird nur erzeugt, wenn nicht leer          *)
(*                      IBM Thinkpad 770 (spsdid38.exe)                    *)
(* 2003.09.10           VGA-ROM Åberspringen (4awl2k28.rom)                *)
(* 2003.11.06           7VRX.F7, 7VRX.F8B, M266_1.40 mit AMIBOOT ROM       *)
(*                      bei Fff40/44/50/54                                 *)
(* 2003.11.06           7VRX.F1: $SIP bei $Fffd4                           *)
(* 2003.11.24           PCI546N3.ROM: 64KiB FF                             *)
(* 2004.10.04           a7032vms.rar\A7032VMS.300                          *)
(*                      P4P81010.AMI(Quelle="$FFFF" in Wirklichkeit lÑnger *)
(*                      recovery BIOS                                      *)
(*                      D:\neu\0chip\aladdrd.exe\x\oldbios.bin (Intel)     *)
(* 2004.10.05           Dateiname recovery.dec                             *)
(*                      lies_quellrom kopiert jetzt mehr als angegeben,    *)
(*                      entpackt damit aber richtig (64 byte->$5300 byte)  *)

uses
  (*$IFDEF DPMI32*)(*$IFDEF DEBUG*)Deb_Link,(*$ENDIF*)(*$ENDIF*)
  VpSysLow,
  VpUtils,
  lzh5x,
  Dos,
  mkdir2,
  AmiDecoS,
  Strings,
  Objects;

const
  datum                 ='1998.03.31..2004.10.04';
  erw                   ='.dec';
  amib_longint          =Ord('A')+Ord('M') shl 8+Ord('I') shl 16+Ord('B') shl 24;
  dateizaehler          :longint=0;
  min_ladeadresse       :longint=$100000;

type
  zeiger_rec            =
    packed record
      ofs,seg           :smallword;
    end;

  zeiger_rec_z          =^zeiger_rec;

  kopf_1994_typ         =
    packed record
      laenge_eingepackt :longint;
      laenge_ausgepackt :longint;
    end;

  ibm_header            =
    packed record
      ami_ofs           :smallword;
      ami_seg           :smallword;
      blocklaenge       :longint;
    end;

  char8                 =array[1..8] of char;

var
  quellrom,
  ausgepackt            :PByteArray;

  d1                    :file;
  position              :zeiger_rec;
  position_l            :longint;
  position_amibiosc     :longint;
  zk                    :string;
  zaehler               :word;
  zielverzeichnis       :string;
  dabei                 :boolean;
  dateilaenge           :longint;
  logischer_anfang      :longint;
  neue_basisadresse_erforderlich :boolean;

  kopf                  :
    packed record
      naechster_block   :zeiger_rec; (* 00 *)
      laenge_eingepackt :smallword;  (* 04 *)
      b6                :byte;       (* 06 *)
      b7                :byte;       (* 07 *)
      ziel_adresse      :zeiger_rec; (* 08 *)
      lc                :longint;    (* 0c *)
      laenge_ausgepackt :longint;    (* 10 *)
    end;                             (* 14 *)

  quellverzeichnis,
  quellname,
  quellerweiterung,
  dateiname             :string;

  anzahl_bloecke        :smallword;

  verweis_1994          :
    packed record
      b0                :byte;
      zielofshi         :byte;
      quellofs          :smallword;
    end;

  kopf_1994             :kopf_1994_typ;

  zielseg               :word;
  zielofs               :word;

  rom                   :array[0..1024*1024-1] of byte;

  mixf0000              :array[0..64*1024-1] of byte;
  mix_used              :boolean=false;

  ami_flash_kopf        : (* I: T00544 *)
    packed record
      kommentar         :array[0..31] of char;
      Logical_area_type :byte;
      logical_area_size :longint;
      load_from_file    :byte;
      reboot_after_update:byte;
      update_entire_image:byte;
      logical_area_name :array[0..23] of char;
      time_stamp        :array[0..14] of char;
      checksum_for_this_header:byte;
      offset_in_image   :longint;
      size_of_image_chunk:longint;
      logical_area_type2:byte;
      last_file_in_chain:byte;
      signature         :array[0..5] of char;
      filename_of_next_file:array[0..15] of char;
      BIOS_reserved     :array[0..15] of char;
    end;

  intel_tabellen_ofs    :longint;

  kopf_ami_intel        :
    packed record
      w0                :smallword; (* $FFFF *)
      typ               :smallword;
      quelle            :longint;
      laenge_eingepackt :longint;
      laenge_ausgepackt :longint;
      ziel              :longint;
      l14               :longint;
    end;

  ladeadresse           :longint;

  l,o,oj,p              :longint;


function frage_adresse(const vorschlag:longint):longint;
  var
    antwort             :string;
    ergebnis            :longint;
    kontrolle           :longint;
  begin
    repeat
      Write('[$',Int2Hex(vorschlag,5),'] ? ');

      if Eof(input) then
        antwort:=''
      else
        ReadLn(antwort);

      Write(^m);

      if antwort='' then
        begin
          kontrolle:=0;
          ergebnis:=vorschlag;
        end
      else
        Val(antwort,ergebnis,kontrolle);

    until kontrolle=0;
    frage_adresse:=ergebnis;
  end;


procedure speichere(var a;anzahl:longint);
  var
    d2                  :file;
  begin
    Assign(d2,zielverzeichnis+dateiname);
    FileMode:=$41;
    Rewrite(d2,1);
    BlockWrite(d2,a,anzahl);
    Close(d2);
  end;


procedure loesche_quellrom;
  begin
    FillChar(quellrom^,$100000,0);
  end;

procedure entpacken(const quelle);
  type
    anfang              =
      packed record
        laenge_eingepackt:longint;
        laenge_ausgepackt:longint;
        daten           :byte;
      end;

  begin

    with anfang(quelle) do
      begin
        FillChar(ausgepackt^,laenge_ausgepackt,$cc);

        if entpacke_lzh5(daten,ausgepackt^,laenge_ausgepackt,laenge_eingepackt) then
           begin
             speichere(ausgepackt^,laenge_ausgepackt);
             Write(Int2Hex(laenge_ausgepackt,8),'  ',dateiname);
           end
        else
          Write(textz_entpackfehler^);
      end;
  end;

function teste_ob_archiv_oder_amibios(const kopf:kopf_1994_typ):boolean;
  begin
    teste_ob_archiv_oder_amibios:=true;

    if  (kopf.laenge_eingepackt<$00e000)
    and (kopf.laenge_eingepackt>$000100)
    and (kopf.laenge_ausgepackt<$011000)
    and (kopf.laenge_ausgepackt>$000100)
     then Exit;

    if kopf.laenge_eingepackt=amib_longint then
      Exit;

    teste_ob_archiv_oder_amibios:=false;
  end;


procedure BlockRead1l(var puffer;const l:longint;laenge:word);
  begin
    if laenge=High(word) then (* P4P81010.AMI: BMP *)
      Move(rom[l],puffer,SizeOf(rom)-l)
    else
      Move(rom[l],puffer,laenge);
  end;

procedure BlockRead1(var puffer;const seg_,ofs_:word;laenge:word);
  begin
    BlockRead1l(puffer,Longint(seg_) shl 4+ofs_,laenge);
  end;

procedure lies_quellroml(const l:longint);
  begin
    BlockRead1l(quellrom^,l,High(word));
  end;

procedure lies_quellrom(const seg_,ofs_:word);
  begin
    lies_quellroml(Longint(seg_) shl 4+ofs_);
  end;

const
  (* aus amidecox/biosgfx@uero.ru *)
  bekannte_block_typen:array[$00..$3f] of pchar=
    ('POST',                        (* 00 *)
     'Setup Server',                (* 01 *)
     'Runtime',                     (* 02 *)
     'DIM',                         (* 03 *)
     'Setup Client',                (* 04 *)
     'Remote Server',               (* 05 *)
     'DMI Data',                    (* 06 *)
     'GreenPC',                     (* 07 *)
     'Interface',                   (* 08 *)
     'MP',                          (* 09 *)
     'Notebook',                    (* 0a *)
     'Int-10',                      (* 0b *)
     'ROM-ID',                      (* 0c *)
     'Int-13',                      (* 0d *)
     'OEM Logo',                    (* 0e *)
     'ACPI Table',                  (* 0f *)
     'ACPI AML',                    (* 10 *)
     'P6 MicroCode',                (* 11 *)
     'Configuration',               (* 12 *)
     'DMI Code',                    (* 13 *)
     'System Health',               (* 14 *)
     'UserDefined',                 (* 15 *)
     '',                            (* 16 *)
     '',                            (* 17 *)
     '? Menu/VGA code',             (* 18 *) (* P07-0014.BIO *)
     'Text mode font',              (* 19 *) (* P07-0014.BIO *)
     'Graphics',                    (* 1a *) (* P07-0014.BIO *)
     '? Setup code',                (* 1b *) (* P07-0014.BIO *)
     '',                            (* 1c *)
     '',                            (* 1d *)
     '',                            (* 1e *)
     '',                            (* 1f *)
     'PCI AddOn ROM',               (* 20 *)
     'Multilanguage',               (* 21 *)
     'UserDefined',                 (* 22 *)
     '',                            (* 23 *)
     '',                            (* 24 *)
     '',                            (* 25 *)
     '',                            (* 26 *)
     '',                            (* 27 *)
     '',                            (* 28 *)
     '',                            (* 29 *)
     'LANG',                        (* 2a *) (* 'GNAL' 'su' *)
     '? PXE ROM',                   (* 2b *) (* P07-0014.BIO *)
     'FONT',                        (* 2c *) (* 'TNOF' *)
     '',                            (* 2d *)
     '? Code+revision',             (* 2e *) (* P07-0014.BIO *)
     '',                            (* 2f *)
     'Font Database',               (* 30 *)
     'OEM Logo Data',               (* 31 *)
     'Graphic Logo Code',           (* 32 *)
     'Graphic Logo Data',           (* 33 *)
     'Action Logo Code',            (* 34 *)
     'Action Logo Data',            (* 35 *)
     'Virus',                       (* 36 *)
     'Online Menu',                 (* 37 *)
     '',                            (* 38 *)
     '',                            (* 39 *)
     '',                            (* 3a *)
     '',                            (* 3b *)
     '',                            (* 3c *)
     'GRFX',                        (* 3d *) (* XFRG *)
     '',                            (* 3e *)
     'TDSS');                       (* 3f *) (* SSDT *)

function block_typ(const t:byte):string;
  var
    tmp:string;
  begin

    tmp:='';

    if t in [low(bekannte_block_typen)..High(bekannte_block_typen)] then
      tmp:=StrPas(bekannte_block_typen[t]);

    if tmp='' then
      tmp:=Int2Hex(kopf.b6,2)+'?';

    while Length(tmp)<20 do tmp:=tmp+' ';
    block_typ:=tmp;
  end;

function bestimme_erweiterung(const t:byte):string;
  begin
    case t of
      $0c:bestimme_erweiterung:='.ver';
      $20:bestimme_erweiterung:='.pci';
      $31:bestimme_erweiterung:='.oem';
      $36:bestimme_erweiterung:='.vir';
    else
          bestimme_erweiterung:=erw;
    end;
  end;

procedure oeffne_datei;
  begin
    Write(dateiname,' ');
    Assign(d1,dateiname);
    FileMode:=$40;
    Reset(d1,1);
    Inc(dateizaehler);
  end;

procedure entpack_versuch(const o:longint);
  begin
    BlockRead1l(kopf_1994,o,SizeOf(kopf_1994));
    if not teste_ob_archiv_oder_amibios(kopf_1994) then Exit;

    Write(':',Int2Hex(o,8),'  ',
                Int2Hex(kopf_1994.laenge_eingepackt,5),'  ????:????  T=??',
                '':16,'-> ');

    dateiname:=Int2Hex(o,8);
    dateiname[1]:='r';
    dateiname:=dateiname+erw;

    loesche_quellrom;
    lies_quellroml(o);
    entpacken(quellrom^);
    Writeln;
  end;

procedure entpacke_recovery;
  var
    i,j                 :longint;

  begin
    for i:=$f0000 to $fffe0 do
      if  (rom[i+ 0]=$66)
      and (rom[i+ 1]=$33)
      and (rom[i+ 2]=$f6)
      and (rom[i+ 3]=$be)
      and (rom[i+ 6]=$66)
      and (rom[i+ 7]=$03)
      and (rom[i+ 8]=$c6)
      and (rom[i+ 9]=$66)
      and (rom[i+10]=$2e)
      and (rom[i+11]=$a3)
      and (rom[i+14]=$c3)
      and (rom[i+15]=$00)
      and (rom[i+16]=$00)
      and (rom[i+17]=$00)
      and (rom[i+18]=$00)
      and (rom[i+19]=$66)
      and (rom[i+20]=$60)
      and (rom[i+21]=$e8) then
        begin
          dateiname:='recovery.dec';
          j:=$f0000+rom[i+4]+rom[i+5] shl 8;
          Write(Int2Hex(j,8),':  ',Int2Hex(kopf_1994_typ(rom[j]).laenge_eingepackt,5),'':13,'recovery            -> ');
          entpacken(rom[j]);
          WriteLn;
          Break;
        end;
  end;

begin
  WriteLn(^m'AMIDECO * V.K. * ',datum);

  if not (ParamCount in [1,2]) then
    begin
      Writeln(textz_benutzung^);
      Halt(1);
    end;

  WriteLn;

  GetMem(quellrom,1024*1024);
  GetMem(ausgepackt,1024*1024);

  FillChar(mixf0000,SizeOf(mixf0000),$cc);

  dateiname:=ParamStr(1);

  (*$IFDEF DEBUG*)
  //dateiname:='I:\daten.ami\2k0301s.rom';

  //dateiname:='I:\daten.ami\626gb14.rom';
  //dateiname:='I:\daten.ami\a5c180s.rom';
  //dateiname:='I:\daten.ami\ae59s.rom';
  //dateiname:='I:\daten.ami\ae5d.rom';
  //dateiname:='I:\ami\p09-0015.bbo';
  //dateiname:='c:\tmp\protbios.bio';
  //dateiname:='M:\t0\p07-0014.bio';
  //dateiname:='M:\t\$0031000.fl1';
  //dateiname:='M:\4awl2k28.zip\4awl2k28.rom';
  //dateiname:='M:\M266_1.40';
  //dateiname:='M:\7VRX.F1';
  //dateiname:='M:\PCI546N3.ROM';
  (*$ENDIF*)

  FSplit(dateiname,quellverzeichnis,quellname,quellerweiterung);

  oeffne_datei;
  dateilaenge:=FileSize(d1);

  if dateilaenge>1*1024*1024 then
    begin
      Close(d1);
      WriteLn;
      WriteLn(textz_datei_ist_zu_lang^,dateilaenge);
      Halt(1);
    end;

  FillChar(rom,SizeOf(rom),0);

  logischer_anfang:=$100000;
  neue_basisadresse_erforderlich:=true;

  repeat
    Seek(d1,0);
    BlockRead(d1,ami_flash_kopf,SizeOf(ami_flash_kopf));
    if StrComp(ami_flash_kopf.signature,'FLASH')=0 then
      with ami_flash_kopf do
        begin
          if neue_basisadresse_erforderlich then
            begin
              Dec(logischer_anfang,logical_area_size);
              if dateizaehler>1 then
                logischer_anfang:=logischer_anfang and $ffff0000;
              neue_basisadresse_erforderlich:=false;
            end;

          Seek(d1,FileSize(d1)-size_of_image_chunk);
          ladeadresse:=frage_adresse(logischer_anfang+offset_in_image);
          if ladeadresse<min_ladeadresse then
            min_ladeadresse:=ladeadresse;
          BlockRead(d1,rom[ladeadresse],size_of_image_chunk);
          Close(d1);
          (*WriteLn;*)

          if (StrComp(logical_area_name,'Boot Block')=0) and (last_file_in_chain=$ff) then
            begin
              last_file_in_chain:=0;
              StrPCopy(filename_of_next_file,quellname+'.BIO');
              neue_basisadresse_erforderlich:=true;
            end;

          if last_file_in_chain=$ff then
            begin
              dateilaenge:=0;
              logischer_anfang:=min_ladeadresse;
              Break;
            end;

          dateiname:=quellverzeichnis+StrPas(filename_of_next_file);
          oeffne_datei;

        end
    else (* normale einzelne Datei *)
      begin
        Dec(logischer_anfang,dateilaenge);
        Seek(d1,0);
        BlockRead(d1,rom[logischer_anfang],dateilaenge);
        Close(d1);
        WriteLn;
        Break;
      end;

  until false;


  zielverzeichnis:=FExpand(ParamStr(2));
  if not (zielverzeichnis[Length(zielverzeichnis)] in ['\','/']) then
    zielverzeichnis:=zielverzeichnis+SysPathSep;

  mkdir_verschachtelt(zielverzeichnis);

  (*$IFDEF DEBUG*)
  dateiname:='BIOS.ROM';
  speichere(rom,SizeOf(rom));
  (*$ENDIF*)


  (*** IBM ohne AMIBIOSC *******************************************)
  if  (StrLComp(@rom[$fe008],'COPR. IBM 1981',Length('COPR. IBM 1981'))=0)
  and (logischer_anfang<=$e0000)
  and ((logischer_anfang and $1ffff)=0)
  and (ibm_header(rom[$e0000]).ami_ofs>=$0000)
  and (ibm_header(rom[$e0000]).ami_ofs<=$0030)
  and ((ibm_header(rom[$e0000]).ami_ofs and $ff0F)=$0000)
  and (ibm_header(rom[$e0000]).ami_seg=$e000)
  and (ibm_header(rom[$e0000]).blocklaenge<1024*1024)
  and (ibm_header(rom[$e0000]).blocklaenge>0) then
    begin
      WriteLn('IBM ROM (Thinkpad 770)..');
      oj:=logischer_anfang;
      o:=oj+2*SizeOf(ibm_header);
      repeat

        if o>=$100000 then
          Halt(0); // end of file

        Write(Int2Hex(oj,8)+':');




        with ibm_header(rom[oj]) do

          if (blocklaenge<=8)  // invalid value
          or (blocklaenge>$20000)
          or ((ami_ofs>0) and (ami_ofs <2*SizeOf(ibm_header)))
          or ((ami_seg and $f000)= $0000)
          or ((ami_seg and $0fff)<>$0000) then
            begin
              if (blocklaenge=0) and (ami_ofs=0) and (ami_seg=0) then
                WriteLn('.')
              else
              if  (Chr(rom[oj+4]) in ['1','2'])
              and (Chr(rom[oj+7]) in ['0','9']) then
                WriteLn('"'+Copy(char8(rom[oj+0]),1,8)+'"')
              else
                WriteLn('?');
              // skip to next 64KB block
              oj:=(o+$0000ffff) and $ffff0000;
              o:=oj+2*SizeOf(ibm_header);
              Continue;
            end;

        with ibm_header(rom[oj]) do
          begin
            p:=(oj and $ffff0000)+(ami_seg-$e000) shl 4+ami_ofs;
            dateiname:=Int2Hex(p,8)+erw;
            Write  ('--> ',Int2Hex(ami_seg,4),':',Int2Hex(ami_ofs,4),',',Int2Hex(blocklaenge,8));
            if ami_ofs>0 then
              begin
                Write  ('  lzh5: ',Int2Hex(kopf_1994_typ(rom[p]).laenge_eingepackt,8),'->');
                entpacken(rom[p]);
                WriteLn;
                o:=Max(o,p+blocklaenge);
              end
            else
              begin
                Write  ('  none: ',Int2Hex(blocklaenge,8));
                speichere(rom[p],blocklaenge);
                WriteLn('=>',Int2Hex(blocklaenge,8),'  ',dateiname);
                o:=Max(o,p+blocklaenge);
              end;
          end;

        Inc(oj,SizeOf(ibm_header));

        (* do not interpret packed data as ibm blocks *)
        with ibm_header(rom[oj and $ff0000]) do
          if  (ami_seg=$e000)
          and (ami_ofs>$0000) (* nicht gepackte Daten enthalten IBM-Block ..*)
          and ((oj and $ffff)>=ami_ofs) then
            begin
              // skip to next 64KB block
              oj:=(o+$0000ffff) and $ffff0000;
              o:=oj+2*SizeOf(ibm_header);
            end;

      until false;

    end;


  (*** Intel ohne AMIBIOSC *****************************************)

  (*-- E000/F000 vertauscht: aladdrd.exe\x\oldbios.bin ---*)
  if  (dateilaenge=$20000)
  and (rom[$efff0]=$EA)
  and (rom[$efff1]=$5B)
  and (rom[$efff2]=$E0)
  and (rom[$efff3]=$00)
  and (rom[$efff4]=$F0) then
    begin
      intel_tabellen_ofs:=MemL[Ofs(rom[$ee000])];

      if  (intel_tabellen_ofs>=$fffe0000)
      and (intel_tabellen_ofs< $ffffe000) then
        begin
          Move(rom[$e0000],rom[$00000],$10000);
          Move(rom[$f0000],rom[$e0000],$10000);
          Move(rom[$00000],rom[$f0000],$10000);
          FillChar(rom[$00000],$10000,0);
          dateilaenge:=0;
        end;
    end;

  intel_tabellen_ofs:=MemL[Ofs(rom[$fe000])];

  if  (dateilaenge=0)
  and (intel_tabellen_ofs>=$fffe0000)
  and (intel_tabellen_ofs< $ffffe000)
   then
    begin

      WriteLn(textz_kopfzeile^);

      repeat

        BlockRead1l(kopf_ami_intel,intel_tabellen_ofs-$fff00000,SizeOf(kopf_ami_intel));

        with kopf_ami_intel do
          begin

            if (laenge_eingepackt=0) or (laenge_eingepackt=$ffffffff) then
              Halt(0);

            if quelle=$ffffffff then
              begin
                Inc(intel_tabellen_ofs,SizeOf(kopf_ami_intel));
                Continue;
              end;

            if laenge_ausgepackt=0 then (* Sprachmodul bei FFFe8800 *)
              begin
                laenge_eingepackt:=MemL[Ofs(rom)+(quelle and $000fffff)+0];
                laenge_ausgepackt:=MemL[Ofs(rom)+(quelle and $000fffff)+4];
                Inc(quelle,4+4);
              end;

            Write(':',Int2Hex(quelle,8),'  ',Int2Hex(laenge_eingepackt,5),'  :',
                  Int2Hex(ziel,8),'  T=',Int2Hex(typ,4),'':17);

            dateiname:=Int2Hex(quelle,8)+erw;

            if laenge_eingepackt=laenge_ausgepackt then
              begin
                speichere(rom[quelle-$fff00000],laenge_ausgepackt);
                Writeln(Int2Hex(kopf_1994.laenge_ausgepackt,8),'  ',dateiname);
              end
            else
              begin
                loesche_quellrom;
                Move(laenge_eingepackt,quellrom^[0],4);
                Move(laenge_ausgepackt,quellrom^[4],4);
                Move(rom[quelle-$fff00000],quellrom^[8],laenge_eingepackt);
                entpacken(quellrom^);
                WriteLn;
              end;

          end;

        Inc(intel_tabellen_ofs,SizeOf(kopf_ami_intel));

      until false;

    end; (* intel *)


  (*** 1995+ mit AMIBIOSC ******************************************)
   position_amibiosc:=$100000;
   while position_amibiosc>0 do
     begin
       if StrLComp(@rom[position_amibiosc-(8+4+6+4)],'AMIBIOSC0',Length('AMIBIOSC0'))=0 then
         Break
       else
         Dec(position_amibiosc,$800);
     end;

  if position_amibiosc>0 then
    begin
      zk[0]:=Chr(Length('AMIBIOSC0627'));
      BlockRead1l(zk[1],position_amibiosc-(8+4+6+4),Ord(zk[0]));

      WriteLn('"',zk,'"');

      BlockRead1l(position,position_amibiosc-4,SizeOf(position));
    end;

  if position_amibiosc=0 then
    begin
      (* AMIBOOT ROM bei FFFFFF40/44/50/54 *)
      if (StrLComp(@rom[$Fff40],'AMIBOOT ROM',Length('AMIBOOT ROM'))=0)
      or (StrLComp(@rom[$Fff44],'AMIBOOT ROM',Length('AMIBOOT ROM'))=0)
      or (StrLComp(@rom[$Fff50],'AMIBOOT ROM',Length('AMIBOOT ROM'))=0)
      or (StrLComp(@rom[$Fff54],'AMIBOOT ROM',Length('AMIBOOT ROM'))=0) then
        begin
          position_amibiosc:=SizeOf(rom)-$10000+(pLongint(@rom[$Fffa0])^ and $ffff);
          if StrLComp(@rom[position_amibiosc],'AMIBIOSC',Length('AMIBIOSC'))=0 then
            begin
              zk[0]:=Chr(Length('AMIBIOSC0627'));
              BlockRead1l(zk[1],position_amibiosc,Ord(zk[0]));

              WriteLn('"',zk,'"');

              BlockRead1l(position,position_amibiosc+$12,SizeOf(position));
            end
          else
            begin
              position_amibiosc:=logischer_anfang+pLongint(@rom[$Fffa0])^;
              if StrLComp(@rom[position_amibiosc],'AMIBIOSC',Length('AMIBIOSC'))=0 then
                begin
                  zk[0]:=Chr(Length('AMIBIOSC0627'));
                  BlockRead1l(zk[1],position_amibiosc,Ord(zk[0]));

                  WriteLn('"',zk,'"');

                  BlockRead1l(position,position_amibiosc+$12,SizeOf(position));
                end
              else
                position_amibiosc:=0;
            end

        end;
    end;

  if position_amibiosc=0 then
    begin

      (* 7VRX.F1: AMIBOOT ROM bei FFFFe000/04, $SIP bei FFFFffd4 *)
      if (StrLComp(@rom[$Fffd4],'$SIP',Length('$SIP'))=0)
      and ((pLongint(@rom[$Fffd0])^ and $fff80000)=$fff80000) then
        begin
          position_amibiosc:=(pLongint(@rom[$Fffd0])^ and $fffff)-$16;
          if StrLComp(@rom[position_amibiosc],'AMIBIOSC',Length('AMIBIOSC'))=0 then
            begin
              zk[0]:=Chr(Length('AMIBIOSC0627'));
              BlockRead1l(zk[1],position_amibiosc,Ord(zk[0]));

              WriteLn('"',zk,'"');

              BlockRead1l(position,position_amibiosc+$12,SizeOf(position));
            end
          else
            position_amibiosc:=0;

        end;
    end;

  if position_amibiosc>0 then
    begin
      WriteLn(textz_kopfzeile^);
      repeat
        if (position.seg=0) or (position.seg=$ffff) then
          begin
            WriteLn(textz_kettenfehler^);
            Halt(1);
          end;

        Write(Int2Hex(position.seg,4),':',Int2Hex(position.ofs,4),'  ');
        BlockRead1(kopf,position.seg,position.ofs,SizeOf(kopf));

        with kopf do
          begin
            if (laenge_eingepackt=0) and (laenge_eingepackt=0) then
              begin
                WriteLn(textz_kettenfehler^);
                Halt(1);
              end;

            Write(Int2Hex(laenge_eingepackt,5),
             '  ',Int2Hex(ziel_adresse.seg,4),
              ':',Int2Hex(ziel_adresse.ofs,4),
             '  ',block_typ(b6));

            loesche_quellrom;
            lies_quellrom(position.seg,position.ofs);

            if (ziel_adresse.seg=0) and (ziel_adresse.ofs=0) then
              begin
                dateiname:=Int2Hex(Longint(position.seg) shl 4+position.ofs,8);
                dateiname[1]:='r';
              end
            else
              dateiname:=Int2Hex(longint(ziel_adresse),8);

            dateiname:=dateiname+bestimme_erweiterung(b6);

            if (b7 and $80)=$80 then
              begin (* nicht komprimiert *)
                write('=> ');
                speichere(quellrom^[4+4+4],laenge_eingepackt);
                Write(Int2Hex(laenge_eingepackt,8),'  ',dateiname);
              end
            else
              begin
                Write('-> ');
                entpacken(quellrom^[4+4+4]);

                (* runtime/post *)
                if (ziel_adresse.seg>=$f000) and (b6 in [0,2]) then
                  begin
                    Write(' +mix');
                    Move(ausgepackt^,
                         mixf0000[(ziel_adresse.seg-$f000) shr 4+ziel_adresse.ofs],
                         laenge_ausgepackt);
                    mix_used:=true;
                  end;
              end;

            WriteLn;
            position:=naechster_block;

          end; (* with kopf *)

      until position.seg=$ffff;

      if mix_used then
        begin
          dateiname:='MIX'+erw;
          speichere(mixf0000,SizeOf(mixf0000));
        end;

      if position_amibiosc<=$f8000 then
        entpack_versuch($f8000);
      if position_amibiosc<=$f0000 then
        entpack_versuch($f0000);

      entpacke_recovery;
      Halt(0);
    end;


  (*** AMIBIOSC bei E000:0000 **************************************)

  if dateilaenge>=128*1024 then
    begin
      zk[0]:=Chr(8+8);
      BlockRead1(zk[1],$e000,$0000,Ord(zk[0]));
      BlockRead1(anzahl_bloecke,$e000,$0010,SizeOf(anzahl_bloecke));
    end
  else
    zk:='';


  if  (Copy(zk,1,8)='AMIBIOSC') (* 1994 *)
  and (anzahl_bloecke<30) (* kein ZÑhler sondern schon die Daten ? *)
   then
    begin
      WriteLn('"',zk,'"');

      dabei:=false; (* F000:1000 noch nicht gefunden *)

      WriteLn(textz_kopfzeile^);
      for zaehler:=0 to anzahl_bloecke-1 do
        begin
          BlockRead1(verweis_1994,$e000,$0012+zaehler*4,SizeOf(verweis_1994));
          position.ofs:=verweis_1994.quellofs;
          position.seg:=$e000;
          BlockRead1(kopf_1994,position.seg,position.ofs,SizeOf(kopf_1994));
          if not teste_ob_archiv_oder_amibios(kopf_1994) then
            begin
              position.seg:=$f000;
              BlockRead1(kopf_1994,position.seg,position.ofs,SizeOf(kopf_1994));
              if not teste_ob_archiv_oder_amibios(kopf_1994) then
                begin
                  WriteLn(textz_kann_quellsegment_nicht_finden^);
                  Halt(1);
                end;
            end;

          if (position.seg=$f000) and (position.ofs=$1000) then
            dabei:=true;

          zielofs:=verweis_1994.zielofshi shl 8;
          Write(Int2Hex(position.seg,4),':',Int2Hex(position.ofs,4),'  ',
            Int2Hex(kopf_1994.laenge_eingepackt,5),'  ????:',
            Int2Hex(zielofs,4),'  T=',Int2Hex(verweis_1994.b0,2),'':16);

          zk[0]:=Chr(8);
          Move(kopf_1994,zk[1],Ord(zk[0]));

          if Copy(zk,1,8-1)='AMIBIOS' then
            begin
              WriteLn('= "',zk,'"');
            end
          else
            begin
              Write('-> ');

              dateiname:=Int2Hex(Longint(position.seg) shl 4+position.ofs,8);
              dateiname[1]:='r';
              dateiname:=dateiname+erw;

              loesche_quellrom;
              lies_quellrom(position.seg,position.ofs);
              entpacken(quellrom^);
              Writeln;

              if verweis_1994.b0 in [0,2] then (* post/runtime *)
                Move(ausgepackt^,mixf0000[zielofs],kopf_1994.laenge_ausgepackt);
            end;

        end; (* FOR *)


      if not dabei then
        begin
          position.ofs:=$1000;
          position.seg:=$f000;
          BlockRead1(kopf_1994,position.seg,position.ofs,SizeOf(kopf_1994));
          if teste_ob_archiv_oder_amibios(kopf_1994) then
            begin

              zielofs:=0;
              Write(Int2Hex(position.seg,4),':',Int2Hex(position.ofs,4),'  ',
                Int2Hex(kopf_1994.laenge_eingepackt,5),'  ????:????  T=??',
                '':16);

              zk[0]:=Chr(8);
              Move(kopf_1994,zk[1],Ord(zk[0]));

              if Copy(zk,1,8-1)='AMIBIOS' then
                begin
                  WriteLn('= "',zk,'"');
                end
              else
                begin
                  Write('-> ');

                  dateiname:=Int2Hex(Longint(position.seg) shl 4+position.ofs,8);
                  dateiname[1]:='r';
                  dateiname:=dateiname+erw;

                  loesche_quellrom;
                  lies_quellrom(position.seg,position.ofs);
                  entpacken(quellrom^);
                  WriteLn;
                end;
            end; (* gÅltig *)
        end; (* dabei *)


      dateiname:='MIX'+erw;
      speichere(mixf0000,SizeOf(mixf0000));
      Halt(0);
    end; (* amibiosc 1994 *)

  (*** Einzelblock *************************************************)
  position_l:=logischer_anfang;

  while StrLComp(@rom[position_l],#$55#$aa,2)=0 do
    begin
      l:=rom[position_l+2]*512;
      dateiname:=Int2Hex(position_l,8)+erw;
      Write(':',Int2Hex(position_l,8),'  ',
                Int2Hex(l,5),'  ????:????  T=??',
                '':16);
      speichere(rom[position_l],l);
      WriteLn('=> ',Int2Hex(l,8),'  ',dateiname);
      Inc(position_l,l);
    end;

  while (position_l<$fe000)
    and ((position_l and $ffff)=0)
    and (rom[position_l] in [0,$ff]) do
      begin
        for zaehler:=1 to 4096-1 do
          if rom[position_l+zaehler]<>rom[position_l] then Break;
        Inc(position_l,4096);
      end;

  while ((position_l and $ffff)<>0) and (rom[position_l] in [0,$ff]) do
    Inc(position_l);

  BlockRead1l(kopf_1994,position_l+$10,SizeOf(kopf_1994));
  if teste_ob_archiv_oder_amibios(kopf_1994) then
    Inc(position_l,$10);
  BlockRead1l(kopf_1994,position_l,SizeOf(kopf_1994));
  if not teste_ob_archiv_oder_amibios(kopf_1994) then
    begin
      WriteLn(textz_datei_ist_kein_amibios^);
      Halt(1);
    end;


  WriteLn(textz_kopfzeile^);
  repeat
    BlockRead1l(kopf_1994,position_l,SizeOf(kopf_1994));

    if kopf_1994.laenge_eingepackt=amib_longint then (* 'ae5d.rom' *)
      begin
        Inc(position_l,$10);
        Continue;
      end;

    if not teste_ob_archiv_oder_amibios(kopf_1994) then
      begin
        position_l:=(position_l and $fffffff0)+$00000010;
        BlockRead1l(kopf_1994,position_l,SizeOf(kopf_1994));
        repeat
          (* Dateiende *)
          if position_l>=High(rom)-$10 then
            Halt(0);

          (* prÅfen *)
          BlockRead1l(kopf_1994,position_l,SizeOf(kopf_1994));
          if kopf_1994.laenge_eingepackt=amib_longint then
            begin
              Inc(position_l,$10);
              Continue;
            end;

          if teste_ob_archiv_oder_amibios(kopf_1994) then
            Break;

          (* Schrott *)
          if  (kopf_1994.laenge_eingepackt<>$ffffffff)
          and (kopf_1994.laenge_eingepackt<>$00000000) then
            begin
              position_l:=(position_l and $ffff0000)+$00010000;
              Continue;
            end;

          Inc(position_l,$10);
        until false;
      end;

    Write(':',Int2Hex(position_l,8),'  ',
                Int2Hex(kopf_1994.laenge_eingepackt,5),'  ????:????  T=??',
                '':16,'-> ');

    dateiname:=Int2Hex(position_l,8);
    dateiname[1]:='r';
    dateiname:=dateiname+erw;

    loesche_quellrom;
    lies_quellroml(position_l);
    entpacken(quellrom^);
    Writeln;

    Inc(position_l,(* 4+4+ *)kopf_1994.laenge_eingepackt);

    if position_l>=High(rom)-$10 then Break;

    BlockRead1l(kopf_1994,position_l,SizeOf(kopf_1994));
    if  ((kopf_1994.laenge_eingepackt and $ff000000)<>0)
    and ((kopf_1994.laenge_ausgepackt and $ff000000)<>0) then
      Inc(position_l,4+4);

  until position_l>=High(rom)-$10;
  Halt(0);
  (* einzel *)

end.

