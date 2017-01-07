unit idMultipartFormDataReader;

interface

{$I IdCompilerDefines.inc}

uses System.SysUtils, System.Classes, IdGlobal, IdGlobalProtocols,
  idMultipartFormData, IdCustomHTTPServer,
  IdCoderQuotedPrintable, IdCoderMIME, IdHeaderList;

type
  TIdMultiPartFormDataStreamReader = class( TIdMultiPartFormDataStream )
  private
    FRequestInfo: TIdHTTPRequestInfo;
  protected
    procedure decodeStream;
  public
    property Fields: TIdFormDataFields read FFields;
    constructor Create( ARequestInfo: TIdHTTPRequestInfo );
  end;

implementation

{ TIdMultiPartFormDataStreamReader }

constructor TIdMultiPartFormDataStreamReader.Create(
  ARequestInfo: TIdHTTPRequestInfo);
begin
  inherited Create;
  FSize := 0;
  FInitialized := False;
  FFields := TIdFormDataFields.Create(Self);
  FRequestInfo := ARequestInfo;
  decodeStream;
end;

procedure TIdMultiPartFormDataStreamReader.decodeStream;
var
  delimi, cadStream: string;
  cabeceras: TIdHeaderList;
  stInfo: TMemoryStream;
  posIniPost, posFinPost, posIniRetorno: Integer;
  cadenaOri: string;
  fieldName: string;
  fieldFileName: string;
  contentType: string;
  charSet: string;
  transferEnconding: string;
  {$IFDEF STRING_IS_ANSI}
    LBytes: TIdBytes;
  {$ENDIF}

  function ReadStringLn( StreamOri: TStream; var cadenaBus: string; char_set: string ): Boolean;
  var
    candidato: Boolean;
    posIniSO: Integer;
    posFinSO: Integer;
    StreamDes: TMemoryStream;
    bleer: Byte;
  begin

    candidato := False;
    StreamDes := TMemoryStream.Create;
    posIniSO := StreamOri.Position;

    cadenaBus := '';

    while ( not candidato ) and ( StreamOri.Position < StreamOri.Size ) do begin

      StreamOri.Read( bleer, 1 );

      if ( bleer = 13 ) then begin

        StreamOri.Read( bleer, 1 );

        if ( bleer = 10 ) then  begin

          candidato := True;
          posFinSO := StreamOri.Position;
          StreamOri.Position := posIniSO;

          if ( posFinSO - 2 - posIniSO > 0 ) then begin

            StreamDes.CopyFrom( StreamOri, posFinSO - 2 - posIniSO );

            StreamDes.Position := 0;

            cadenaBus := IdGlobalProtocols.ReadStringAsCharset( StreamDes, char_set );

          end;

          StreamOri.Position := posFinSO;

        end;

      end;

    end;


    StreamDes.Free;
    Result := candidato;

  end;
begin
  {$IFDEF STRING_IS_ANSI}
  LBytes := nil;
  {$ENDIF}

  if ( ExtractHeaderItem( FRequestInfo.RawHeaders.Values[ 'Content-Type' ] ) <> 'multipart/form-data' ) then
    Exit;

  cabeceras := TIdHeaderList.Create( TIdHeaderQuotingType.QuoteHTTP );

  delimi := FRequestInfo.RawHeaders.Params['Content-Type', 'boundary'];

  FBoundary := delimi;

  FRequestContentType := sContentTypeFormData + FBoundary;

  FRequestInfo.PostStream.Position := 0;

  if ( ReadStringLn( FRequestInfo.PostStream, cadenaOri, FRequestInfo.CharSet ) ) then begin

    while ( cadenaOri = '--' + delimi )  and
          ( FRequestInfo.PostStream.Position < FRequestInfo.PostStream.Size ) do begin

      if ( ReadStringLn( FRequestInfo.PostStream, cadenaOri, FRequestInfo.CharSet ) ) then begin

        while ( cadenaOri <> '' ) and
          ( FRequestInfo.PostStream.Position < FRequestInfo.PostStream.Size ) do begin

          cabeceras.Add( cadenaOri );
          ReadStringLn( FRequestInfo.PostStream, cadenaOri, FRequestInfo.CharSet );

        end;

        fieldName := cabeceras.Params[ 'Content-Disposition', 'name' ];
        fieldFileName := cabeceras.Params[ 'Content-Disposition', 'filename' ];


        contentType := ExtractHeaderItem( cabeceras.Values[ 'Content-Type' ] );
        charSet := cabeceras.Params[ 'Content-Type', 'charset' ];

        transferEnconding := cabeceras.Values[ 'Content-Transfer-Encoding' ];

        stInfo := TMemoryStream.Create;
        posIniPost := FRequestInfo.PostStream.Position;
        posFinPost := posIniPost;

        ReadStringLn( FRequestInfo.PostStream, cadenaOri, FRequestInfo.CharSet );

        while ( cadenaOri <> '--' + delimi ) and ( cadenaOri <> '--' + delimi + '--' )  and
          ( FRequestInfo.PostStream.Position < FRequestInfo.PostStream.Size ) do begin

          posFinPost := FRequestInfo.PostStream.Position;
          ReadStringLn( FRequestInfo.PostStream, cadenaOri, FRequestInfo.CharSet );

        end;

        posIniRetorno := FRequestInfo.PostStream.Position;

        FRequestInfo.PostStream.Position := posIniPost;

        if ( posFinPost - 2 - posIniPost > 0 ) then begin

          if ( fieldFileName <> '' ) then begin

            stInfo.CopyFrom( FRequestInfo.PostStream, posFinPost - 2 - posIniPost );

            if ( LowerCase( transferEnconding ) = 'quoted-printable' ) then begin

              stInfo.Position := 0;

              cadStream := ReadStringFromStream( stInfo );

              stInfo.Clear;
              stInfo.Position := 0;

              TIdDecoderQuotedPrintable.DecodeStream( cadStream, stInfo );

            end else if ( LowerCase( transferEnconding ) = 'base64' ) then begin

              stInfo.Position := 0;

              cadStream := ReadStringFromStream( stInfo );

              stInfo.Clear;
              stInfo.Position := 0;

              TIdDecoderMIME.DecodeStream( cadStream, stInfo );

            end;

            stInfo.Position := 0;

            AddFormField( fieldName, contentType, charSet, stInfo, fieldFileName );

          end else begin

            stInfo.CopyFrom( FRequestInfo.PostStream, posFinPost - 2 - posIniPost );

            cadStream := '';

            stInfo.Position := 0;

            {$IFDEF STRING_IS_ANSI}

            ReadTIdBytesFromStream( stInfo, LBytes, stInfo.Size );

            {$ENDIF}

            if ( LowerCase( transferEnconding ) = '7bit' ) then begin

              {$IFDEF STRING_IS_UNICODE}

              cadStream := ReadStringFromStream( stInfo, -1, IndyTextEncoding_ASCII );

              {$ELSE}

              CheckByteEncoding( LBytes, IndyTextEncoding_ASCII, CharsetToEncoding( charSet ) );

              {$ENDIF}

            end else if ( LowerCase( transferEnconding ) = 'quoted-printable' ) then begin

              {$IFDEF STRING_IS_UNICODE}

              cadStream := ReadStringFromStream( stInfo );

              cadStream := TIdDecoderQuotedPrintable.DecodeString( cadStream, CharsetToEncoding( charSet ) );

              {$ELSE}

              BytesToRaw( LBytes, cadStream, Length( LBytes ) );

              LBytes := TIdDecoderQuotedPrintable.DecodeBytes( cadStream );

              {$ENDIF}

            end else if ( LowerCase( transferEnconding ) = 'base64' ) then begin

              {$IFDEF STRING_IS_UNICODE}

              cadStream := ReadStringFromStream( stInfo );

              cadStream := TIdDecoderMIME.DecodeString( cadStream, CharsetToEncoding( charSet ) );

              {$ELSE}

              BytesToRaw( LBytes, cadStream, Length( LBytes ) );

              LBytes := TIdDecoderMIME.DecodeBytes( cadStream );

              {$ENDIF}

            end else if ( LowerCase( transferEnconding ) = '8bit' ) or ( LowerCase( transferEnconding ) = 'binary' ) then begin

              {$IFDEF STRING_IS_UNICODE}

              cadStream := ReadStringAsCharset( stInfo, charSet );

              {$ENDIF}

            end;

            {$IFDEF STRING_IS_ANSI}

            BytesToRaw( LBytes, cadStream, Length( LBytes ) );

            {$ENDIF}

            AddFormField( fieldName, cadStream, charSet, contentType );

            stInfo.Free;

          end;

        end;

        FRequestInfo.PostStream.Position := posIniRetorno;

        cabeceras.Clear;

      end;

    end;

  end;

end;

end.
