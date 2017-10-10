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

function Merge-PDF($files, $path, $filename) {
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
    
    $outPath = [System.IO.Path]::combine($path,$filename);
    $output.Save($outPath)            
}

$path = $(get-location).Path

$tmpPath = [System.IO.Path]::combine($path,'tmp');
New-Item $tmpPath -type directory -Force


$outputPackageName = [string]::Format("{0} REV {1} .zip", $artworkName, $rev) 
$zipPath = [System.IO.Path]::combine($path,$outputPackageName)

Write-Host "Packaging gerbers...."
Compress-Archive -Force -Path .\*.gbr -DestinationPath $zipPath -ErrorVariable archiveError
if ($archiveError) {
	Write-Host "Packaging error!"
	exit 1
}

Write-Host "Packaging auto insert...."
$autoInsertName = [string]::Format("AUTO-INSERT-REV{0}.csv", $rev)
$autoInsertTmp = [System.IO.Path]::combine($tmpPath,$autoInsertName)
$insertFile = Get-ChildItem -Filter AUTO*INSERT*.csv | Select-Object -First 1 -ExpandProperty FullName | Copy-Item -Destination $autoInsertTmp

Compress-Archive -Update -Path $autoinsertTmp -DestinationPath $zipPath -ErrorVariable archiveError
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
Merge-Pdf $files $path $releasePlotsName

Write-Host "Packaging release plots...."

Compress-Archive -Update -Path $releasePlotsName -DestinationPath $zipPath -ErrorVariable archiveError
if ($archiveError) {
	Write-Host "Packaging error!"
	exit 1
}

Remove-Item $tmpPath -Force -Recurse

exit 0
