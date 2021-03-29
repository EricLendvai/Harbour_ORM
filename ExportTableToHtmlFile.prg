#include "hb_vfp.ch"
#include "dbinfo.ch"   // for the export to html file

#define CHECKMARK "✓"

//=================================================================================================================
function ExportTableToHtmlFile(par_alias,par_html_file,par_Description,par_MaxKBSize,par_HeaderRepeatFrequency,par_DisplayStructure)
local l_Folder          := ""
local l_FileName        := ""
local l_FileExtension   := ""
local l_FullFileName
local l_DeleteFileError
local l_Result          := ""
local l_select          := iif(used(),select(),0)
local l_recno
local l_NumberOfFields
local l_FieldCounter
local l_html
local l_html_table_header
local l_html_record
local l_FileHandle
local l_FieldValue
local l_CurrentFileSize       := 0
local l_MaxFileSize           := (hb_DefaultValue(par_MaxKBSize,0) * 1024)
local l_WriteBufferSize       := 100 * 1024  // To chunck the writting of the html file by max 100 Kb.
local l_HeaderRepeatFrequency := hb_DefaultValue(par_HeaderRepeatFrequency,0)   // Number of rows between headers
local l_RowsAfterHeader       := 0
local l_Description           := hb_DefaultValue(par_Description,'')
local l_DisplayStructure      := hb_DefaultValue(par_DisplayStructure,.f.)
local l_Structure             := {}
local l_FieldNilInfo
local l_FieldValue_len
local l_FieldType
local l_pos
local l_FieldTags
//local l_CheckMarck := "✓"  //hb_utf8Chr(10003)

hb_FNameSplit(par_html_file,@l_Folder,@l_FileName,@l_FileExtension)

if empty(l_FileName)
    l_Result := "Missing File Name"
else
    if empty(l_FileExtension)
        l_FileExtension := ".html"
    endif
    if empty(l_Folder)  // If the file name passed as parameter was not folder specific, use the current folder
        l_Folder := hb_cwd()
    endif
    l_FullFileName := l_Folder+l_FileName+l_FileExtension

    if hb_DirExists(l_Folder)
        if hb_FileExists(l_FullFileName)
            l_DeleteFileError := DeleteFile(l_FullFileName)  //https://docs.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-
        else
            l_DeleteFileError := 0
        endif
        if l_DeleteFileError == 0
            l_FileHandle = FCreate(l_FullFileName)
            if l_FileHandle > 0
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

                // l_html += '<div class="TableDescription"><b>Alias: </b>'+par_alias+'</div>'
                l_html += '<div class="TableDescription">'
                    l_html += '<span><b>Alias: </b>'+par_alias+'</span>'+Replicate('&nbsp;',10)
                    if !empty(l_Description)
                        l_html += '<span><b>Description: </b>'+l_Description+'</span>'+Replicate('&nbsp;',10)
                    endif
                    l_html += '<span><b>Content Time: </b>'+hb_TtoC(hb_DateTime(),"YYYY-MM-DD","HH:MM:SS")+'</span>'
                l_html += '</div>'

                select (par_alias)
                l_NumberOfFields := FCount()
                for l_FieldCounter := 1 to l_NumberOfFields
                    AAdd(l_Structure,{FieldName(l_FieldCounter),hb_FieldType(l_FieldCounter),hb_FieldLen(l_FieldCounter),hb_FieldDec(l_FieldCounter)})
                endfor

                if RecCount() == 0
                    l_html += '<div>No records on file</div>'
                else
                    l_recno := RecNo()

                    l_html += '<table border="1" cellpadding="3" cellspacing="0">'

                    l_html_table_header := ''
                    l_html_table_header += '<tr>'
                    l_html_table_header += '<td class="THead CellCenter">#</td>'
                    
                    for l_FieldCounter := 1 to l_NumberOfFields
                        l_html_table_header += '<td class="THead">'+l_Structure[l_FieldCounter,1]+'</td>'
                    endfor
                    l_html_table_header += '</tr>'

                    l_html += l_html_table_header

                    scan all
                        if (l_MaxFileSize > 0) .and. (l_CurrentFileSize + len(l_html) >= l_MaxFileSize)
                            exit
                        endif

                        if l_HeaderRepeatFrequency > 0
                            if l_RowsAfterHeader >= l_HeaderRepeatFrequency
                                l_html += l_html_table_header
                                l_RowsAfterHeader := 0
                            endif
                            l_RowsAfterHeader += 1
                        endif

                        l_html_record := ''
                        l_html_record += '<tr>'
                        l_html_record += '<td class="THead CellCenter">'+trans(RecNo())+'</td>'
                        for l_FieldCounter := 1 to l_NumberOfFields
                            l_FieldValue   := FieldGet(l_FieldCounter)
                            l_FieldNilInfo := DBFieldInfo( DBS_ISNULL, l_FieldCounter )
                            if ((!hb_IsNIL(l_FieldNilInfo) .and. l_FieldNilInfo) .or. hb_IsNIL(l_FieldValue))   //Method to handle mem:tables and SQLMIX tables
                                l_html_record += '<td class="isnull"></td>'
                            else
                                do case
                                case ValType(l_FieldValue) == 'C'
                                    l_FieldValue_len := len(l_FieldValue)
                                    l_FieldValue := hb_StrReplace(l_FieldValue,{'&#94;' => '^'       ,;
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
                                    l_html_record += '<td class="tooltip"><span class="tooltiptext">'+trans(l_FieldValue_len)+'</span>'+l_FieldValue+'</td>'
                                // case ValType(l_FieldValue) == 'B'
                                //     l_html_record += '<td>Binary</td>'
                                otherwise
                                    l_html_record += '<td>'+hb_CStr(l_FieldValue)+'</td>'
                                endcase
                            endif

                        endfor
                        l_html_record += '</tr>'

                        if len(l_html)+len(l_html_record) > l_WriteBufferSize
                            l_CurrentFileSize += FWrite(l_FileHandle,l_html)
                            l_html        := l_html_record
                            l_html_record := ''
                        else
                            l_html += l_html_record
                        endif
                    endscan
                    l_html += '</table>'
                    dbGoto(l_recno)
                endif

                if l_DisplayStructure
                    l_html += '<br><br>'
                    l_html += '<div class="TableDescription">'
                        l_html += '<span><b>Structure</b></span>'
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

                    for l_FieldCounter := 1 to l_NumberOfFields

                        l_pos := at(":",l_Structure[l_FieldCounter,2])
                        if empty(l_pos)
                            l_FieldType := l_Structure[l_FieldCounter,2]
                            l_FieldTags := ""
                        else
                            l_FieldType := left(l_Structure[l_FieldCounter,2],l_pos-1)
                            l_FieldTags := substr(l_Structure[l_FieldCounter,2],l_pos+1)
                        endif

                        l_html += '<tr>'
                        l_html += '<td>'+l_Structure[l_FieldCounter,1]+'</td>'
                        l_html += '<td align="center">'+l_FieldType+'</td>'
                        l_html += '<td align="center">'+trans(l_Structure[l_FieldCounter,3])+'</td>'
                        l_html += '<td align="center">'+trans(l_Structure[l_FieldCounter,4])+'</td>'
                        l_html += '<td align="center">'+iif("N"$l_FieldTags,CHECKMARK,"")+'</td>'          // Allow Nulls
                        l_html += '<td align="center">'+iif("+"$l_FieldTags,CHECKMARK,"")+'</td>'          // Auto Increment
                        l_html += '<td align="center">'+iif("B"$l_FieldTags,CHECKMARK,"")+'</td>'          // Binary
                        l_html += '<td align="center">'+iif("U"$l_FieldTags,CHECKMARK,"")+'</td>'          // Unicode
                        l_html += '<td align="center">'+iif("Z"$l_FieldTags,CHECKMARK,"")+'</td>'          // Compressed
                        l_html += '</tr>'
                    endfor

                    l_html += '</table>'
                endif

                l_html += '</html>'
                l_CurrentFileSize += FWrite(l_FileHandle,l_html)
                FClose(l_FileHandle)
            else
                l_Result := "Failed to creat file"
            endif
        else
            l_Result := "Previous copy of file could not be deleted"
        endif
    else
        l_Result := "Folder does not exists"
    endif

    select (l_select)
endif

return l_Result
//=================================================================================================================
