$path = "D:\jamui_service\admin_panel\lib\features\providers\presentation\pages\providers_page.dart"
$lines = [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)

# Find broken line around 396
$brokenIdx = -1
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "updates\['re\s+final pendingAppsCount") {
        $brokenIdx = $i
        break
    }
}
Write-Host "Broken index 1: $brokenIdx"

# Find rejection reason invalid line around 1348
$rejectIdx = -1
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].StartsWith("}") -and $lines[$i].Contains("(Rejection Reason)")) {
        $rejectIdx = $i
        break
    }
}
Write-Host "Broken index 2: $rejectIdx"

if ($brokenIdx -ge 0 -and $rejectIdx -ge 0) {
    # Build the corrected file content
    $newLines = [System.Collections.Generic.List[string]]::new()
    
    # 1. Add lines before brokenIdx
    for ($i = 0; $i -lt $brokenIdx; $i++) {
        $line = $lines[$i]
        # Check if DropdownButtonFormField at 339 needs isExpanded: true
        if ($line.Contains("DropdownButtonFormField<String>(") -and -not $lines[$i+1].Contains("isExpanded: true,")) {
            $newLines.Add($line)
            $newLines.Add("                        isExpanded: true,")
            continue
        }
        $newLines.Add($line)
    }

    # 2. Insert the restored closing logic for _showProviderDetailModal and header for build
    $newLines.Add("                      updates['rejectionReason'] = FieldValue.delete();")
    $newLines.Add("                    }")
    $newLines.Add("                    Navigator.pop(ctx);")
    $newLines.Add("                    _updateProviderField(p['id'], updates);")
    $newLines.Add("                  },")
    $newLines.Add("                  icon: const Icon(Icons.check, size: 16),")
    $newLines.Add("                  label: const Text('सेव करें / अपडेट करें (Save)'),")
    $newLines.Add("                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),")
    $newLines.Add("                ),")
    $newLines.Add("              ],")
    $newLines.Add("            );")
    $newLines.Add("          },")
    $newLines.Add("        );")
    $newLines.Add("      },")
    $newLines.Add("    );")
    $newLines.Add("  }")
    $newLines.Add("")
    $newLines.Add("  @override")
    $newLines.Add("  Widget build(BuildContext context) {")
    $newLines.Add("    final pendingAppsCount = _customApplications.where((a) => a['status'] == 'pending_review').length;")

    # 3. Add lines between brokenIdx+1 and rejectIdx
    for ($i = $brokenIdx + 1; $i -lt $rejectIdx; $i++) {
        $line = $lines[$i]
        # Check if DropdownButtonFormField at 857 needs isExpanded: true
        if ($line.Contains("DropdownButtonFormField<String>(") -and -not $lines[$i+1].Contains("isExpanded: true,")) {
            $newLines.Add($line)
            $newLines.Add("                          isExpanded: true,")
            continue
        }
        $newLines.Add($line)
    }

    # 4. Close the class _ProvidersPageState properly
    $newLines.Add("}")

    # Write back with UTF-8 encoding
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($path, $newLines, $utf8WithoutBom)
    Write-Host "File fixed successfully! Total lines: " $newLines.Count
} else {
    Write-Host "Error: Could not locate broken indices."
}
