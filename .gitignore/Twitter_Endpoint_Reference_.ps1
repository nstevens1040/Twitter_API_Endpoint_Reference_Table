$r = Execute-WebRequest -METHOD GET `
-URI "https://nanick.org/twitterapi.html" `
-NO_COOKIE
$c22 = @(); $c22 += @($r.HtmlDocument.body.getElementsByClassName("c22_link"))

$dt = [System.Data.DataTable]::New()
$dt.Columns.Add([System.Data.DataColumn]::New("Endpoint",[string]))
$dt.Columns.Add([System.Data.DataColumn]::New("API",[string]))
$dt.Columns.Add([System.Data.DataColumn]::New("API version",[string]))
$dt.Columns.Add([System.Data.DataColumn]::New("Authentication",[string]))
$dt.Columns.Add([System.Data.DataColumn]::New("Http Method",[string]))
$dt.Columns.Add([System.Data.DataColumn]::New("Endpoint Uri",[string]))
$start = [datetime]::Now
$all = $c22.Count
for($i = 0; $i -lt $c22.Count; $i++){
    Remove-Variable href,s,auth_methods,a,text,index,api,fullUri,ver -ea 0
    $href = $c22[$i] |% href
    $a = "$($c22[$i] |% outerHtml)" -replace " href"," target=`"_blank`" href"
    $endpointMethod = "$($c22[$i] |% innerText)".Split(' ')[0]
    if($href -and $endpointMethod -in @("DELETE","GET","POST","PUT")){
        $api = $href.Split('/')[5]
        if($api -ne 'twitter-ads-api'){
            $s = Execute-WebRequest -METHOD GET -URI $href -NO_COOKIE -SILENT
            $fullUri = @($s.HtmlDocument.body.getElementsByTagName("code")).Where({$_.InnerText -match "^https"})[0] |% innerText
            if($fullUri){
                $ver = $fullUri.Split('/')[3]
                if($ver -notin @("1.1","2")){
                    remove-variable ver -ea 0
                }
            }
            @($s.HtmlDocument.body.getElementsByTagName("table")).ForEach({
                if(@($_.All).Where({$_.innerText -match 'Requires authentication' -or $_.innerText -match 'Authentication methods' -and ($_.TagName -in @("TD","TH"))})){
                    $text = @(); $text += @($_.All).Where({$_.TagName -in @("TD","TH")}).ForEach({ $_ |% innerText })
                    $index = [System.Array]::IndexOf($text,"Authentication methods`r`nsupported by this endpoint") + 1
                    if($index -ne 0){
                        $auth_methods = $text[$index] -replace "(\r)(\n)",","
                    } else {
                        $index = [System.Array]::IndexOf($text,'Requires authentication?') + 1
                        if($index -ne 0){
                            $auth_methods = $text[$index]
                        }
                    }
                }
            })
            if(!$auth_methods){
                $tstring = (@($s.HtmlDocument.body.getElementsByTagName("table")[0].all).Where({$_.TagName -eq 'TD'}).ForEach({$_ |% innerText}) | Out-String)
                if($tstring -match 'user auth' -and $tstring -match 'app auth'){
                    $auth_methods = 'app auth, user auth'
                }
            }
            if(!$auth_methods){
                $auth_methods = @($s.HtmlDocument.body.getElementsByTagName("table")[0].all).Where({$_.TagName -eq 'TD'})[0].innerText -replace "(\r)(\n)",","
            }
            if($auth_methods){
                $auth_methods = $auth_methods -replace "^(\s*)",'' -replace "(\s*)$",''
                switch($auth_methods){
                    "Yes" {
                        $auth_methods = "OAuth 1.0a User context or OAuth 2.0 Bearer token"
                    }
                    "Yes (user context only)" {
                        $auth_methods = "OAuth 1.0a User context"
                    }
                }
                if($auth_methods -notmatch "OAuth" -and $auth_methods -notmatch "No"){
                    $auth_methods = $null
                }
            }
            $row = $dt.NewRow()
            $row.Endpoint = $a
            $row.API = $api
            if($ver){
                $row."API version" = $ver
            }
            if($auth_methods){
                $row.Authentication = $auth_methods
            }
            if($endpointMethod){
                $row."Http Method" = $endpointMethod
            }
            if($fullUri){
                $row."Endpoint Uri" = $fullUri
            }
            $dt.Rows.Add($row)
            remove-variable row -ea 0
        }
        if($i -gt 0){
            $ite = $i
            $now = [datetime]::Now
            $ela = ($now - $start) |% totalSeconds
            $rem = ($ela*($all/$ite)) - $ela
            ($now.AddSeconds($rem) - $now) | select Days,hours,Minutes,Seconds,Milliseconds | % { $ts = "$("{0:d2}" -f ($_ | % days)) days :: $("{0:d2}" -f ($_ | % hours)) hours :: $("{0:d2}" -f ($_ | % minutes)) minutes :: $("{0:d2}" -f ($_ | % seconds)) seconds ::$("{0:d3}" -f ($_ | % milliseconds))ms" }
            Write-Progress -PercentComplete (($ite/$all)*100) -Status "$($ite) of $($all) :: $((($ite/$all)*100).ToString("0.00",[cultureinfo]::InvariantCulture))% :: $($ts) remaining" -Activity "$($c22[$i] |% href)"
        }
    }
}
if([io.file]::Exists("$($ENV:USERPROFILE)\Desktop\Twitter-Endpoint-Table.csv")){
    [io.file]::Delete("$($ENV:USERPROFILE)\Desktop\Twitter-Endpoint-Table.csv")
}
if([io.file]::Exists("$($ENV:USERPROFILE)\Desktop\Twitter-Endpoint-Table.html")){
    [io.file]::Delete("$($ENV:USERPROFILE)\Desktop\Twitter-Endpoint-Table.html")
}
$dt | export-csv .\Twitter-Endpoint-Table.csv -NoTypeInformation
excel2table.exe .\Twitter-Endpoint-Table.csv .\Twitter-Endpoint-Table.html

