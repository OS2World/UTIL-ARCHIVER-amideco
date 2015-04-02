program ibmdeco;

uses
  lzh5x,
  VpUtils,
  Objects;

type
  ibm_header            =
    packed record
      ami_ofs           :smallword;
      ami_seg           :smallword;
      blocklaenge       :longint;
    end;

  ami_header            =
    packed record
      laenge_eingepackt :longint;
      laenge_ausgepackt :longint;
      daten             :byte;
    end;


var
  d:file;
  p1,p2:pByteArray;
  l,o,oj,p:longint;

begin
  GetMem(p1,1024*1024);
  GetMem(p2,1024*1024);

  if paramcount<>1 then
    begin
      //Assign(d,'$0031000.fl1')
      Writeln('IBMDECO * IBM (AMI?) BIOS flash unpacker * V.K. 2002.10.07..08');
      WriteLn('IBMDECO <sourcefile>');
      Halt(99);
    end
  else
    Assign(d,ParamStr(1));

  Reset(d,1);
  l:=FileSize(d);
  BlockRead(d,p1^,l);
  Close(d);


  oj:=0;
  o:=oj+2*SizeOf(ibm_header);
  repeat
    Write(Int2Hex(oj,8)+':');

    if o>=l then
      begin
        WriteLn('EOF.');
        Break; // end of file
      end;



    with ibm_header(p1^[oj]) do

      if (blocklaenge<=8)  // invalid valued
      or (blocklaenge>$20000)
      or ((ami_ofs>0) and (ami_ofs <2*SizeOf(ibm_header)))
      or ((ami_seg and $f000)= $0000)
      or ((ami_seg and $0fff)<>$0000) then
        begin
          if (blocklaenge=0) and (ami_ofs=0) and (ami_seg=0) then
            WriteLn('.')
          else
            WriteLn('?');
          // skip to next 64KB block
          oj:=(o+$0000ffff) and $ffff0000;
          o:=oj+2*SizeOf(ibm_header);
          Continue;
        end;

    with ibm_header(p1^[oj]) do
      begin
        p:=(oj and $ffff0000)+(ami_seg-$e000) shl 4+ami_ofs;
        if ami_ofs>0 then
          with ami_header(p1^[p]) do
            begin
              WriteLn('--> ',Int2Hex(ami_seg,4),':',Int2Hex(ami_ofs,4),',',Int2Hex(blocklaenge,8));
              Write  ('  lzh5: ',Int2Hex(laenge_eingepackt,8),'->',Int2Hex(laenge_ausgepackt,8),' ');
              entpacke_lzh5(daten,p2^,laenge_ausgepackt,laenge_eingepackt);
              Assign(d,Int2Hex(p,8)+'.dec');
              ReWrite(d,1);
              BlockWrite(d,p2^,laenge_ausgepackt);
              Close(d);
              WriteLn;
              o:=Max(o,p+blocklaenge);
            end
        else
          begin
            WriteLn('--> ',Int2Hex(ami_seg,4),':',Int2Hex(ami_ofs,4),',',Int2Hex(blocklaenge,8));
            Write  ('  none: ',Int2Hex(blocklaenge,8));
            Assign(d,Int2Hex(p,8)+'.dec');
            ReWrite(d,1);
            BlockWrite(d,p1^[p],blocklaenge);
            Close(d);
            WriteLn;
            o:=Max(o,p+blocklaenge);
          end;
      end;

    Inc(oj,SizeOf(ibm_header));

  until false;

  Dispose(p1);
  Dispose(p2);
end.
