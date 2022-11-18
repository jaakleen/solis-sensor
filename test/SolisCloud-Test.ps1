$xml = [xml] (Get-Content "$($PSCommandPath ? ($PSCommandPath + '\..') : (get-location))\app.config")
#==============================================================================
# Constants please fill in yours 
#[api_secrets]
$soliscloud_api_id = $xml.SelectSingleNode('//add[@key="KeyID"]').Value  
$soliscloud_api_secret = $xml.SelectSingleNode('//add[@key="KeySecret"]').Value  
$soliscloud_api_url = $xml.SelectSingleNode('//add[@key="url"]').Value  
#==============================================================================
# Other constants

$VERB = "POST"
$CONTENT_TYPE = "application/json"
$USER_STATION_LIST = '/v1/api/userStationList'
$INVERTER_LIST = '/v1/api/inveterList'
$INVERTER_DETAIL = '/v1/api/inveterDetail'
$PLANT_DETAIL = '/v1/api/stationDetail'

function log {
    [CmdletBinding()]
	Param ([string] $msg)
    #"""log a message prefixed with a date/time format yyyymmdd hh:mm:ss"""
    Write-Output (get-date).tostring('yyyyMMdd hh:mm:ss') + ': ' + $msg
}

function get_solis_cloud_data {
    [CmdletBinding()]
    param([string] $url_part, $data)
        #"""get solis cloud data"""
        $en = Get-WinSystemLocale #should be english US
        $date = [string](get-date -AsUTC -format $en.DateTimeFormat.RFC1123Pattern) #  "Tue, 21 Aug 2012 17:29:18 GMT"
        $jdata = $data #should be json otherwise convert to json
        $utf8 = New-Object -TypeName System.Text.UTF8Encoding
        $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
        $md5Hash = $md5.ComputeHash($utf8.GetBytes($jdata))
        $md5B64 =[Convert]::ToBase64String($md5Hash)
        $lines = @($VERB, $md5B64, $CONTENT_TYPE, $date, $url_part)
        $jlines  = [string]::Join("`n", $lines)
        $hmacsha1 = New-Object System.Security.Cryptography.HMACSHA1
        $hmacsha1.Key = [Text.Encoding]::UTF8.GetBytes($soliscloud_api_secret)
        $signature = $hmacsha1.ComputeHash([Text.Encoding]::UTF8.GetBytes($jlines))

        $authorization = 'API ' + $SOLISCLOUD_API_ID + ':' +
        [Convert]::ToBase64String($signature)
        $headers = @{
                'Content-MD5' = $md5B64;
                'Content-Type'= $CONTENT_TYPE;
                'Date' = $date ;
                'Authorization'= $authorization
            }
        $resultData = $null
        $Retry = 0
        while (!$resultData -And $Retry -lt 10) {
            $responseError = $null;
            $Error.clear()

            $response = Invoke-WebRequest -Method Post -uri ($SOLISCLOUD_API_URL+$url_part) -Headers $headers -Body $jdata
            if ($response -and $Response.content) {
                $responseHash = ConvertFrom-Json -AsHashtable $response.Content
                if ($responseHash['success']) {
                    $resultData = $responseHash['data']
                } else {
                    $responseError = $responseHash['msg']
                }
            } else {
                if ($response) {
                    $responseError = $response.RawContent
                } else {
                    $responseError = $Error[0]
                }
            }
            if ($responseError) {
                Start-Sleep -Seconds 5
            }
            $retry++
        }
        if (!$resultData) {
            {
                throw $responseError;
            }
        }
        return $resultData #-> str
}

$Body = '{"pageNo":1,"pageSize":10}'
$response = get_solis_cloud_data -url_part $USER_STATION_LIST -data $body

$USER_STATION_LIST
$response['page']['records'][0]
<# This doesn't work
$ID=$response['page']['records'][0]['id']
$body = "{""Id"":""$ID""}"
 $response = get_solis_cloud_data -url_part $PLANT_DETAIL -data $body
 $PLANT_DETAIL
 $response
#>

$Body = '{"pageNo":1,"pageSize":10}'
$response = get_solis_cloud_data -url_part $INVERTER_LIST -data $body

$INVERTER_LIST
$response['page']['records'][0]

$ID=$response['page']['records'][0]['id']
$body = "{""Id"":""$ID""}"
$response = get_solis_cloud_data -url_part $INVERTER_DETAIL -data $body

$INVERTER_DETAIL
$response



