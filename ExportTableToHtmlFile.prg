#include "hb_el.ch"
#include "dbinfo.ch"   // for the export to html file

#define CHECKMARK "✓"

//=================================================================================================================
function ExportTableToHtmlFile(par_cAlias,par_cFullPathFileName,par_cDescription,par_nMaxKBSize,par_nHeaderRepeatFrequency,par_lDisplayStructure)
local l_cFolder          := ""
local l_cFileName        := ""
local l_cFileExtension   := ""
local l_cFullFileName
local l_nDeleteFileError
local l_cResult          := ""
local l_nSelect          := iif(used(),select(),0)
local l_iRecno
local l_iReccount
local l_nRecordSize
local l_nNumberOfFields
local l_nFieldCounter
local l_html
local l_html_table_header
local l_html_record
local l_nFileHandle
local l_xFieldValue
local l_nCurrentFileSize       := 0
local l_nMaxFileSize           := (hb_DefaultValue(par_nMaxKBSize,0) * 1024)
local l_nWriteBufferSize       := 100 * 1024  // To chunck the writting of the html file by max 100 Kb.
local l_nHeaderRepeatFrequency := hb_DefaultValue(par_nHeaderRepeatFrequency,0)   // Number of rows between headers
local l_nRowsAfterHeader       := 0
local l_cDescription           := hb_DefaultValue(par_cDescription,'')
local l_lDisplayStructure      := hb_DefaultValue(par_lDisplayStructure,.f.)
local l_aStructure             := {}
local l_xFieldNilInfo
local l_xFieldValue_len
local l_cFieldType
local l_nPos
local l_cFieldTags
local l_cTableFullPath
//local l_CheckMarck := "✓"  //hb_utf8Chr(10003)

if !empty(par_cAlias) .and. (par_cAlias)->(used())
    l_nRecordSize := (par_cAlias)->(RecSize())
    if l_nRecordSize <= 0
        l_nRecordSize := (par_cAlias)->(DBINFO(DBI_GETRECSIZE))
    endif

    l_cTableFullPath := (par_cAlias)->(DBINFO(DBI_FULLPATH))

    hb_FNameSplit(par_cFullPathFileName,@l_cFolder,@l_cFileName,@l_cFileExtension)

    if empty(l_cFileName)
        l_cResult := "Missing File Name"
    else
        if empty(l_cFileExtension)
            l_cFileExtension := ".html"
        endif
        if empty(l_cFolder)  // If the file name passed as parameter was not folder specific, use the current folder
            l_cFolder := hb_cwd()
        endif
        l_cFullFileName := l_cFolder+l_cFileName+l_cFileExtension

        if hb_DirExists(l_cFolder)
            if hb_FileExists(l_cFullFileName)
                l_nDeleteFileError := DeleteFile(l_cFullFileName)  //https://docs.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-
            else
                l_nDeleteFileError := 0
            endif
            if l_nDeleteFileError == 0
                l_nFileHandle = FCreate(l_cFullFileName)
                if l_nFileHandle > 0
                    l_html := '<!DOCTYPE html>'
                    l_html += '<html>'
                    l_html += '<head><meta charset="utf-8"></head>'
                    l_html += '<style>'
                    l_html += 'table, th, td {border: 1px solid black;}'
                    l_html += 'table {border-collapse: collapse;}'
                    l_html += 'td {vertical-align: top;}'
                    l_html += '.isnull { background-color: #eeeeee;}'
                    l_html += '.TableDescription { padding-bottom: 10px; }'
                    l_html += '.THead {background-color: #0084ff; color: #ffffff;}'
                    l_html += '.CellCenter {text-align:center;}'

                    //See https://www.w3schools.com/css/css_tooltip.asp
                    //Tooltip text
                    l_html += '.tooltip .tooltiptext {visibility: hidden;width: 120px;background-color: black;color: #fff;text-align: center;padding: 5px 0;border-radius: 6px;position: absolute;z-index: 1;}'

                    //Show the tooltip text when you mouse over the tooltip container
                    l_html += '.tooltip:hover .tooltiptext {visibility: visible;}'

                    l_html += '</style>'

                    select (par_cAlias)
                    l_nNumberOfFields := FCount()
                    for l_nFieldCounter := 1 to l_nNumberOfFields
                        AAdd(l_aStructure,{FieldName(l_nFieldCounter),hb_FieldType(l_nFieldCounter),hb_FieldLen(l_nFieldCounter),hb_FieldDec(l_nFieldCounter)})
                    endfor

                    l_iReccount := RecCount()

                    // l_html += '<div class="TableDescription"><b>Alias: </b>'+par_cAlias+'</div>'
                    l_html += '<div class="TableDescription">'
                        l_html += '<span><b>Alias: </b>'+par_cAlias+'</span>'
                        if l_iReccount > 0
                            l_html += Replicate('&nbsp;',5)+'<span><b>Rows: </b>'+Trans(l_iReccount)+'</span>'
                            l_html += Replicate('&nbsp;',5)+'<span><b>Columns: </b>'+Trans(l_nNumberOfFields)+'</span>'
                        endif
                        
                        if !empty(l_cDescription)
                            l_html += Replicate('&nbsp;',10)+'<span><b>Description: </b>'+l_cDescription+'</span>'
                        endif
                        l_html += Replicate('&nbsp;',10)+'<span><b>Content Time: </b>'+hb_TtoC(hb_DateTime(),"YYYY-MM-DD","HH:MM:SS")+'</span>'
                    l_html += '</div>'

                    if l_iReccount == 0
                        l_html += '<div>No records on file</div>'
                    else
                        l_iRecno := RecNo()

                        l_html += '<table border="1" cellpadding="3" cellspacing="0">'

                        l_html_table_header := ''
                        l_html_table_header += '<tr>'
                        l_html_table_header += '<td class="THead CellCenter">#</td>'
                        
                        for l_nFieldCounter := 1 to l_nNumberOfFields
                            l_html_table_header += '<td class="THead">'+l_aStructure[l_nFieldCounter,1]+'</td>'
                        endfor
                        l_html_table_header += '</tr>'

                        l_html += l_html_table_header

                        scan all
                            if (l_nMaxFileSize > 0) .and. (l_nCurrentFileSize + len(l_html) >= l_nMaxFileSize)
                                exit
                            endif

                            if l_nHeaderRepeatFrequency > 0
                                if l_nRowsAfterHeader >= l_nHeaderRepeatFrequency
                                    l_html += l_html_table_header
                                    l_nRowsAfterHeader := 0
                                endif
                                l_nRowsAfterHeader += 1
                            endif

                            l_html_record := ''
                            l_html_record += '<tr>'
                            l_html_record += '<td class="THead CellCenter">'+trans(RecNo())+'</td>'
                            for l_nFieldCounter := 1 to l_nNumberOfFields
                                l_xFieldValue   := FieldGet(l_nFieldCounter)
                                l_xFieldNilInfo := DBFieldInfo( DBS_ISNULL, l_nFieldCounter )
                                if ((!hb_IsNIL(l_xFieldNilInfo) .and. l_xFieldNilInfo) .or. hb_IsNIL(l_xFieldValue))   //Method to handle mem:tables and SQLMIX tables
                                    l_html_record += '<td class="isnull"></td>'
                                else
                                    do case
                                    case ValType(l_xFieldValue) == 'C'
                                        l_xFieldValue_len := len(l_xFieldValue)
                                        l_xFieldValue := hb_StrReplace(l_xFieldValue,{'&#94;' => '^'       ,;
                                                                                    '&amp;' => '&'       ,;
                                                                                    '&AMP;' => '&'       ,;
                                                                                    '&'     => '&amp;'   ,;
                                                                                    '<'     => '&lt;'    ,;
                                                                                    '>'     => '&gt;'    ,;
                                                                                    '  '    => ' &nbsp;' ,;
                                                                                    chr(10) => ''        ,;
                                                                                    chr(13) => '<br>'    ,;
                                                                                    '^'     => '&#94;'    ;
                                                                                    })
                                        l_html_record += '<td class="tooltip"><span class="tooltiptext">'+trans(l_xFieldValue_len)+'</span>'+l_xFieldValue+'</td>'
                                    // case ValType(l_xFieldValue) == 'B'
                                    //     l_html_record += '<td>Binary</td>'
                                    case ValType(l_xFieldValue) == 'D'
                                        l_html_record += '<td>'+hb_DtoC(l_xFieldValue,"yyyy-mm-dd") +'</td>'
                                    case ValType(l_xFieldValue) == 'T'
                                        if hb_Sec(l_xFieldValue) == int(hb_Sec(l_xFieldValue))
                                            l_html_record += '<td>'+hb_TtoC(l_xFieldValue,"yyyy-mm-dd","hh:mm:ss p") +'</td>'
                                        else
                                            l_html_record += '<td>'+hb_TtoC(l_xFieldValue,"yyyy-mm-dd","hh:mm:ss.fff p") +'</td>'
                                        endif
                                    otherwise
                                        l_html_record += '<td>'+hb_CStr(l_xFieldValue)+'</td>'
                                    endcase
                                endif

                            endfor
                            l_html_record += '</tr>'

                            if len(l_html)+len(l_html_record) > l_nWriteBufferSize
                                l_nCurrentFileSize += FWrite(l_nFileHandle,l_html)
                                l_html        := l_html_record
                                l_html_record := ''
                            else
                                l_html += l_html_record
                            endif
                        endscan
                        l_html += '</table>'
                        dbGoto(l_iRecno)
                    endif

                    if l_lDisplayStructure
                        l_html += '<br><br>'
                        l_html += '<div class="TableDescription">'
                            l_html += '<span><b>Structure</b></span>'
                            l_html += '<span>&nbsp;&nbsp;&nbsp;Number of Fields:</span><span>&nbsp;'+Alltrim(Str(l_nNumberOfFields))+'</span>'
                            if l_nRecordSize > 0    // Fails to work in SQLMix, _M_ more research needed.
                                l_html += '<span>&nbsp;&nbsp;Record size:</span><span>&nbsp;'+Alltrim(Str(l_nRecordSize))+'</span>'
                            endif
                            if !empty(l_cTableFullPath)  // For SQLMix table this is empty
                                l_html += '<span>&nbsp;&nbsp;Table Path :</span><span>&nbsp;'+l_cTableFullPath+'</span>'
                            endif

                        l_html += '</div>'
                        l_html += '<table border="1" cellpadding="3" cellspacing="0">'
                        l_html += '<tr>'
                        l_html += '<td class="THead CellCenter">Name</td>'
                        l_html += '<td class="THead CellCenter">Type</td>'
                        l_html += '<td class="THead CellCenter">Length</td>'
                        l_html += '<td class="THead CellCenter">Decimals</td>'
                        l_html += '<td class="THead CellCenter">Allow<br>Nulls</td>'
                        l_html += '<td class="THead CellCenter">Auto<br>Increment</td>'
                        l_html += '<td class="THead CellCenter">Binary</td>'
                        l_html += '<td class="THead CellCenter">Unicode</td>'
                        l_html += '<td class="THead CellCenter">Compressed</td>'
                        l_html += '</tr>'

                        for l_nFieldCounter := 1 to l_nNumberOfFields

                            l_nPos := at(":",l_aStructure[l_nFieldCounter,2])
                            if empty(l_nPos)
                                l_cFieldType := l_aStructure[l_nFieldCounter,2]
                                l_cFieldTags := ""
                            else
                                l_cFieldType := left(l_aStructure[l_nFieldCounter,2],l_nPos-1)
                                l_cFieldTags := substr(l_aStructure[l_nFieldCounter,2],l_nPos+1)
                            endif

                            l_html += '<tr>'
                            l_html += '<td>'+l_aStructure[l_nFieldCounter,1]+'</td>'
                            l_html += '<td align="center">'+l_cFieldType+'</td>'
                            l_html += '<td align="center">'+trans(l_aStructure[l_nFieldCounter,3])+'</td>'
                            l_html += '<td align="center">'+trans(l_aStructure[l_nFieldCounter,4])+'</td>'
                            l_html += '<td align="center">'+iif("N"$l_cFieldTags,CHECKMARK,"")+'</td>'          // Allow Nulls
                            l_html += '<td align="center">'+iif("+"$l_cFieldTags,CHECKMARK,"")+'</td>'          // Auto Increment
                            l_html += '<td align="center">'+iif("B"$l_cFieldTags,CHECKMARK,"")+'</td>'          // Binary
                            l_html += '<td align="center">'+iif("U"$l_cFieldTags,CHECKMARK,"")+'</td>'          // Unicode
                            l_html += '<td align="center">'+iif("Z"$l_cFieldTags,CHECKMARK,"")+'</td>'          // Compressed
                            l_html += '</tr>'
                        endfor

                        l_html += '</table>'
                    endif

                    l_html += '</html>'
                    l_nCurrentFileSize += FWrite(l_nFileHandle,l_html)
                    FClose(l_nFileHandle)
                else
                    l_cResult := "Failed to creat file"
                endif
            else
                l_cResult := "Previous copy of file could not be deleted"
            endif
        else
            l_cResult := "Folder does not exists"
        endif

        select (l_nSelect)
    endif
endif

return l_cResult
//=================================================================================================================
