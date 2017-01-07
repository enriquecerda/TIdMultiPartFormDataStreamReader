# TIdMultiPartFormDataStreamReader

TIdMultiPartFormDataStreamReader Allows you to read multipart / form-data type streaming and store all the contents of the form in fields, is an extension of TIdMultiPartFormDataStream of the Indy project.
The constructor receive TIdHTTPRequestInfo Object from your events of TIdHTTPServer, how get, post, etc.

Example:

procedure TForm1.IdHTTPServer1CommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);

var
  decoder: TIdMultiPartFormDataStreamReader;

begin

  decoder := TIdMultiPartFormDataStreamReader.Create( ARequestInfo );
  
  for  x := 0 to decoder.Fields.Count - 1 do begin

    campo := decoder.Fields.Items[ x ];
    
    memo1.Lines.Add( campo.ContentType );
    
    Memo1.Lines.Add( campo.ContentTransfer );
    
    memo1.Lines.Add( campo.Charset );
    
    Memo1.Lines.Add( campo.FieldName );

    if ( campo.FileName <> '' ) then begin

      if ( campo.FieldStream <> nil ) then begin
      
        Memo1.Lines.Add( 'stream' );
        
        ima := TPngImage.Create;
        
        ima.LoadFromStream( campo.FieldStream );
        
        Image1.Picture.Assign( ima );
        
        ima.Free;
        
      end;
      
    end else
    
      memo1.Lines.Add( campo.FieldValue );

    Memo1.Lines.Add( '++++++++++++++++++++++++++++++' );

   end;
   
 end;


 
