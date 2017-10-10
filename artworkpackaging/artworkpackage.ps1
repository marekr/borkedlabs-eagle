[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,Position=1)]
	[string]$artworkName,
	
	[Parameter(Mandatory=$True,Position=2)]
	[string]$rev,
	
	[Parameter(Mandatory=$False)]
	[string]$path
)

<#
Creates a "$artworkName REV $rev.zip"

Renames auto-insert to AUTO-INSERT-REV$rev.csv
Creates releaseplots as $artworkName-REV$rev-RELEASEPLOTS.pdf

 #>

function Merge-PDF($files, $path, $outputFilePath) {
    $typePath = [System.IO.Path]::combine($PSScriptRoot,"deps\PdfSharp.dll");
    Add-Type -Path $typePath

    $output = New-Object PdfSharp.Pdf.PdfDocument            
    $PdfReader = [PdfSharp.Pdf.IO.PdfReader]            
    $PdfDocumentOpenMode = [PdfSharp.Pdf.IO.PdfDocumentOpenMode]                        
    
	foreach($file in $files) {
		foreach($i in (Get-ChildItem $path $file -Recurse)) {
			$input = New-Object PdfSharp.Pdf.PdfDocument
            $input = $PdfReader::Open($i.fullname, $PdfDocumentOpenMode::Import)
            for ($i=0; $i -lt $input.PageCount; $i++) {
                $page = $input.Pages[$i]
                $output.AddPage($page)
            }
		}
	}
    
    $output.Save($outputFilePath)            
}

$path = $(get-location).Path

$packagePath = [System.IO.Path]::combine($path,'package');
New-Item $packagePath -type directory -Force


$outputPackageName = [string]::Format("{0} REV {1} .zip", $artworkName, $rev) 
$zipPath = [System.IO.Path]::combine($path,$outputPackageName)

Get-ChildItem $from -Filter *.gbr -Recurse | % {Copy-Item -Path $_ -Destination  $packagePath -Force -Container }
Write-Host "Packaging gerbers...."
if ($archiveError) {
	Write-Host "Packaging error!"
	exit 1
}

Write-Host "Packaging drill...."
Get-ChildItem $from -Filter *.drill.dri -Recurse | % {Copy-Item -Path $_ -Destination  $packagePath -Force -Container }
Get-ChildItem $from -Filter *.drill.txt -Recurse | % {Copy-Item -Path $_ -Destination  $packagePath -Force -Container }
if ($archiveError) {
	Write-Host "Packaging error!"
	exit 1
}

Write-Host "Packaging auto insert...."
$autoInsertName = [string]::Format("AUTO-INSERT-REV{0}.csv", $rev)
$autoInsertPkged = [System.IO.Path]::combine($packagePath,$autoInsertName)
$insertFile = Get-ChildItem -Filter AUTO*INSERT*.csv | Select-Object -First 1 -ExpandProperty FullName | Copy-Item -Destination $autoInsertPkged

Compress-Archive -Update -Path $autoInsertPkged -DestinationPath $zipPath -ErrorVariable archiveError
if ($archiveError) {
	Write-Host "Packaging error!"
	exit 1
}

Write-Host "Creating merged release plot...."

$files = @(
    "*top_drawing*.pdf",
    "*bottom_drawing*.pdf",
    "*drill.txt*.pdf",
    "*top_silk*.pdf",
    "*top_copper*.pdf",
    "*bottom_copper*.pdf",
    "*bottom_silk*.pdf"
   )
   
$releasePlotsName = [string]::Format("{0}-REV{1}-RELEASEPLOTS.pdf", $artworkName, $rev) 
$releasePlotsPkged = [System.IO.Path]::combine($packagePath,$releasePlotsName)
Merge-Pdf $files $path $releasePlotsPkged

$archiveSource = [System.IO.Path]::combine($packagePath,'*')
Compress-Archive -Force -Path $archiveSource -DestinationPath $zipPath -ErrorVariable archiveError

Remove-Item $packagePath -Force -Recurse

exit 0
