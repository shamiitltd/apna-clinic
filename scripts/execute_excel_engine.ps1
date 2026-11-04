# -*- coding: utf-8 -*-
# Apna Clinic - Master Sheet Real Excel 16.0 COM Automation & Execution Script

$ErrorActionPreference = "Stop"

$finalWorkbook = "D:\Apna Clinic\APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx"
$validationCopy = "D:\Apna Clinic\APNA_CLINIC_MASTER_SHEET_VALIDATION_COPY.xlsx"
$testFlowCopy = "D:\Apna Clinic\APNA_CLINIC_MASTER_SHEET_TEST_FLOW.xlsx"
$jsonOutputFile = "D:\Apna Clinic\scripts\excel_execution_results.json"

Write-Host "======================================================================"
Write-Host "APNA CLINIC MASTER SHEET REAL EXCEL COM EXECUTION & VALIDATION"
Write-Host "======================================================================"

$results = [ordered]@{
    "excel_version" = ""
    "template_file" = $finalWorkbook
    "sheets_detected" = 0
    "sheet_names" = @()
    "named_ranges_detected" = 0
    "named_ranges" = @()
    "broken_named_ranges" = 0
    "formula_cells_checked" = 0
    "formula_errors_detected" = 0
    "formula_error_details" = @()
    "circular_references" = 0
    "unexpected_merged_cells" = 0
    "calculated_values" = @{}
    "test_flow_executed" = $false
    "test_flow_records_inserted" = 0
    "test_flow_recalculated_values" = @{}
    "status" = "RUNNING"
}

$excel = $null
$wb = $null

try {
    Write-Host "[1/6] Initializing Microsoft Excel Application via COM..."
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $results["excel_version"] = $excel.Version
    Write-Host "      Detected Microsoft Excel Version: $($excel.Version)"

    Write-Host "[2/6] Opening Master Sheet Template: $finalWorkbook"
    $wb = $excel.Workbooks.Open($finalWorkbook, $false, $false)
    $results["sheets_detected"] = $wb.Sheets.Count

    foreach ($sh in $wb.Sheets) {
        $results["sheet_names"] += $sh.Name
    }
    Write-Host "      Detected $($results['sheets_detected']) Worksheets."

    Write-Host "[3/6] Inspecting Excel Named Ranges..."
    $results["named_ranges_detected"] = $wb.Names.Count
    foreach ($nr in $wb.Names) {
        $nrObj = @{
            "name" = $nr.Name
            "refers_to" = $nr.RefersTo
        }
        $results["named_ranges"] += $nrObj
        if ($nr.RefersTo -match "#REF!") {
            $results["broken_named_ranges"] += 1
            Write-Host "      [ERROR] Broken Named Range: $($nr.Name) -> $($nr.RefersTo)"
        }
    }
    Write-Host "      Validated $($results['named_ranges_detected']) Named Ranges. Broken: $($results['broken_named_ranges'])"

    Write-Host "[4/6] Forcing Excel Full Formula Recalculation ($($excel.Version))..."
    $excel.CalculateFullRebuild()

    # Inspect all sheets for errors (#REF!, #VALUE!, #NAME?, #DIV/0!, circular refs)
    Write-Host "      Scanning all sheets for formula errors and anomalies..."
    $errorPatterns = @("#REF!", "#VALUE!", "#DIV/0!", "#NAME?", "#N/A", "#NULL!", "#NUM!")

    foreach ($sh in $wb.Sheets) {
        $used = $sh.UsedRange
        if ($null -ne $used) {
            $rows = $used.Rows.Count
            $cols = $used.Columns.Count

            # Check circular reference on sheet
            try {
                if ($null -ne $sh.CircularReference) {
                    $results["circular_references"] += 1
                    Write-Host "      [ERROR] Circular Reference on sheet '$($sh.Name)' at cell $($sh.CircularReference.Address)"
                }
            } catch {}

            for ($r = 1; $r -le $rows; $r++) {
                for ($c = 1; $c -le $cols; $c++) {
                    $cell = $used.Cells.Item($r, $c)
                    $txt = [string]$cell.Text
                    $val = [string]$cell.Value2
                    $form = [string]$cell.Formula

                    if ($form -match "^=") {
                        $results["formula_cells_checked"] += 1
                        foreach ($pat in $errorPatterns) {
                            if ($txt -match [regex]::Escape($pat) -or $val -match [regex]::Escape($pat)) {
                                $results["formula_errors_detected"] += 1
                                $errItem = @{
                                    "sheet" = $sh.Name
                                    "cell" = $cell.Address
                                    "formula" = $form
                                    "error_text" = $txt
                                }
                                $results["formula_error_details"] += $errItem
                                Write-Host "      [ERROR] Formula error on '$($sh.Name)' cell $($cell.Address): $form -> $txt"
                            }
                        }
                    }

                    if ($cell.MergeCells -and $r -gt 1) {
                        $results["unexpected_merged_cells"] += 1
                    }
                }
            }
        }
    }

    Write-Host "      Formula cells scanned: $($results['formula_cells_checked']). Errors detected: $($results['formula_errors_detected'])"

    # Extract calculated values for 10_BILLING and 19_REPORTING
    Write-Host "      Capturing Excel's real-time evaluated values..."
    $wsBilling = $wb.Sheets.Item("10_BILLING")
    $calcBilling = @()
    for ($r = 2; $r -le 5; $r++) {
        $calcBilling += @{
            "row" = $r
            "invoice_id" = [string]$wsBilling.Cells.Item($r, 1).Text
            "subtotal" = [double]$wsBilling.Cells.Item($r, 6).Value2
            "discount" = [double]$wsBilling.Cells.Item($r, 7).Value2
            "tax" = [double]$wsBilling.Cells.Item($r, 8).Value2
            "total_formula" = [string]$wsBilling.Cells.Item($r, 9).Formula
            "total_amount_calc" = [double]$wsBilling.Cells.Item($r, 9).Value2
            "paid_amount" = [double]$wsBilling.Cells.Item($r, 10).Value2
            "due_formula" = [string]$wsBilling.Cells.Item($r, 11).Formula
            "due_amount_calc" = [double]$wsBilling.Cells.Item($r, 11).Value2
            "status" = [string]$wsBilling.Cells.Item($r, 12).Text
        }
    }
    $results["calculated_values"]["10_BILLING"] = $calcBilling

    $wsRep = $wb.Sheets.Item("19_REPORTING")
    $calcReporting = @()
    for ($r = 2; $r -le 15; $r++) {
        $calcReporting += @{
            "row" = $r
            "kpi_id" = [string]$wsRep.Cells.Item($r, 1).Text
            "metric_name" = [string]$wsRep.Cells.Item($r, 2).Text
            "formula" = [string]$wsRep.Cells.Item($r, 3).Formula
            "evaluated_value" = [string]$wsRep.Cells.Item($r, 3).Text
            "evaluated_numeric" = $wsRep.Cells.Item($r, 3).Value2
        }
    }
    $results["calculated_values"]["19_REPORTING"] = $calcReporting

    Write-Host "[5/6] Saving Validation Copy with Excel-Evaluated Caches: $validationCopy"
    $wb.SaveCopyAs($validationCopy)
    $wb.Close($false)
    $wb = $null

    # STEP 4: REAL TEST DATA FLOW IN EXCEL
    Write-Host "[6/6] Executing Real Data Flow Scenario on Temporary Copy..."
    Copy-Item -Path $finalWorkbook -Destination $testFlowCopy -Force
    $wbTest = $excel.Workbooks.Open($testFlowCopy, $false, $false)

    # 1. Insert 3 new patients
    $wsPat = $wbTest.Sheets.Item("05_PATIENTS")
    $patStart = $wsPat.UsedRange.Rows.Count + 1
    $wsPat.Cells.Item($patStart, 1).Value2 = "PAT-000011"
    $wsPat.Cells.Item($patStart, 2).Value2 = "P-2026-0011"
    $wsPat.Cells.Item($patStart, 3).Value2 = "Amit"
    $wsPat.Cells.Item($patStart, 4).Value2 = "Patel"
    $wsPat.Cells.Item($patStart, 5).Value2 = "Amit Patel"
    $wsPat.Cells.Item($patStart, 6).Value2 = 42
    $wsPat.Cells.Item($patStart, 7).Value2 = "MALE"
    $wsPat.Cells.Item($patStart, 8).Value2 = "9876543011"
    $wsPat.Cells.Item($patStart, 9).Value2 = "amit@test.com"
    $wsPat.Cells.Item($patStart, 10).Value2 = "404 Relief Road"
    $wsPat.Cells.Item($patStart, 11).Value2 = "Ahmedabad"
    $wsPat.Cells.Item($patStart, 12).Value2 = "Gujarat"
    $wsPat.Cells.Item($patStart, 13).Value2 = "380001"
    $wsPat.Cells.Item($patStart, 14).Value2 = "B+"
    $wsPat.Cells.Item($patStart, 15).Value2 = "NONE"
    $wsPat.Cells.Item($patStart, 16).Value2 = "HYPERTENSION"
    $wsPat.Cells.Item($patStart, 17).Value2 = "2026-09-29"
    $wsPat.Cells.Item($patStart, 18).Value2 = "ACTIVE"
    $wsPat.Cells.Item($patStart, 19).Value2 = "GRANTED"
    $wsPat.Cells.Item($patStart, 20).Value2 = "2026-09-29 09:00:00"
    $wsPat.Cells.Item($patStart, 21).Value2 = "2026-09-29 09:00:00"
    $wsPat.Cells.Item($patStart, 22).Value2 = "USR-000002"
    $wsPat.Cells.Item($patStart, 23).Value2 = "USR-000002"

    $wsPat.Cells.Item($patStart + 1, 1).Value2 = "PAT-000012"
    $wsPat.Cells.Item($patStart + 1, 2).Value2 = "P-2026-0012"
    $wsPat.Cells.Item($patStart + 1, 3).Value2 = "Meena"
    $wsPat.Cells.Item($patStart + 1, 4).Value2 = "Deshmukh"
    $wsPat.Cells.Item($patStart + 1, 5).Value2 = "Meena Deshmukh"
    $wsPat.Cells.Item($patStart + 1, 6).Value2 = 29
    $wsPat.Cells.Item($patStart + 1, 7).Value2 = "FEMALE"
    $wsPat.Cells.Item($patStart + 1, 8).Value2 = "9876543012"
    $wsPat.Cells.Item($patStart + 1, 9).Value2 = "meena@test.com"
    $wsPat.Cells.Item($patStart + 1, 10).Value2 = "12 FC Road"
    $wsPat.Cells.Item($patStart + 1, 11).Value2 = "Pune"
    $wsPat.Cells.Item($patStart + 1, 12).Value2 = "Maharashtra"
    $wsPat.Cells.Item($patStart + 1, 13).Value2 = "411004"
    $wsPat.Cells.Item($patStart + 1, 14).Value2 = "O+"
    $wsPat.Cells.Item($patStart + 1, 15).Value2 = "NONE"
    $wsPat.Cells.Item($patStart + 1, 16).Value2 = "NONE"
    $wsPat.Cells.Item($patStart + 1, 17).Value2 = "2026-09-29"
    $wsPat.Cells.Item($patStart + 1, 18).Value2 = "ACTIVE"
    $wsPat.Cells.Item($patStart + 1, 19).Value2 = "GRANTED"
    $wsPat.Cells.Item($patStart + 1, 20).Value2 = "2026-09-29 09:15:00"
    $wsPat.Cells.Item($patStart + 1, 21).Value2 = "2026-09-29 09:15:00"
    $wsPat.Cells.Item($patStart + 1, 22).Value2 = "USR-000002"
    $wsPat.Cells.Item($patStart + 1, 23).Value2 = "USR-000002"

    $wsPat.Cells.Item($patStart + 2, 1).Value2 = "PAT-000013"
    $wsPat.Cells.Item($patStart + 2, 2).Value2 = "P-2026-0013"
    $wsPat.Cells.Item($patStart + 2, 3).Value2 = "Rohan"
    $wsPat.Cells.Item($patStart + 2, 4).Value2 = "Iyer"
    $wsPat.Cells.Item($patStart + 2, 5).Value2 = "Rohan Iyer"
    $wsPat.Cells.Item($patStart + 2, 6).Value2 = 35
    $wsPat.Cells.Item($patStart + 2, 7).Value2 = "MALE"
    $wsPat.Cells.Item($patStart + 2, 8).Value2 = "9876543013"
    $wsPat.Cells.Item($patStart + 2, 9).Value2 = "rohan@test.com"
    $wsPat.Cells.Item($patStart + 2, 10).Value2 = "88 Indiranagar"
    $wsPat.Cells.Item($patStart + 2, 11).Value2 = "Bengaluru"
    $wsPat.Cells.Item($patStart + 2, 12).Value2 = "Karnataka"
    $wsPat.Cells.Item($patStart + 2, 13).Value2 = "560038"
    $wsPat.Cells.Item($patStart + 2, 14).Value2 = "A+"
    $wsPat.Cells.Item($patStart + 2, 15).Value2 = "PENICILLIN"
    $wsPat.Cells.Item($patStart + 2, 16).Value2 = "NONE"
    $wsPat.Cells.Item($patStart + 2, 17).Value2 = "2026-09-29"
    $wsPat.Cells.Item($patStart + 2, 18).Value2 = "ACTIVE"
    $wsPat.Cells.Item($patStart + 2, 19).Value2 = "GRANTED"
    $wsPat.Cells.Item($patStart + 2, 20).Value2 = "2026-09-29 09:30:00"
    $wsPat.Cells.Item($patStart + 2, 21).Value2 = "2026-09-29 09:30:00"
    $wsPat.Cells.Item($patStart + 2, 22).Value2 = "USR-000002"
    $wsPat.Cells.Item($patStart + 2, 23).Value2 = "USR-000002"

    # 2. Insert 2 new doctors
    $wsDoc = $wbTest.Sheets.Item("04_DOCTORS")
    $docStart = $wsDoc.UsedRange.Rows.Count + 1
    $wsDoc.Cells.Item($docStart, 1).Value2 = "DOC-000005"
    $wsDoc.Cells.Item($docStart, 2).Value2 = "D-05"
    $wsDoc.Cells.Item($docStart, 3).Value2 = "Dr. Vikram Seth"
    $wsDoc.Cells.Item($docStart, 4).Value2 = "Cardiology"
    $wsDoc.Cells.Item($docStart, 5).Value2 = "MD, DM"
    $wsDoc.Cells.Item($docStart, 6).Value2 = "MCI-2015-4421"
    $wsDoc.Cells.Item($docStart, 7).Value2 = "9811223305"
    $wsDoc.Cells.Item($docStart, 8).Value2 = "vikram@apnaclinic.com"
    $wsDoc.Cells.Item($docStart, 9).Value2 = "ROOM-000001"
    $wsDoc.Cells.Item($docStart, 10).Value2 = 700.0
    $wsDoc.Cells.Item($docStart, 11).Value2 = 20
    $wsDoc.Cells.Item($docStart, 12).Value2 = "ACTIVE"
    $wsDoc.Cells.Item($docStart, 13).Value2 = "2026-09-01"
    $wsDoc.Cells.Item($docStart, 14).Value2 = "2026-09-01 09:00:00"
    $wsDoc.Cells.Item($docStart, 15).Value2 = "2026-09-01 09:00:00"

    $wsDoc.Cells.Item($docStart + 1, 1).Value2 = "DOC-000006"
    $wsDoc.Cells.Item($docStart + 1, 2).Value2 = "D-06"
    $wsDoc.Cells.Item($docStart + 1, 3).Value2 = "Dr. Ananya Ray"
    $wsDoc.Cells.Item($docStart + 1, 4).Value2 = "Dermatology"
    $wsDoc.Cells.Item($docStart + 1, 5).Value2 = "MD (DVL)"
    $wsDoc.Cells.Item($docStart + 1, 6).Value2 = "MCI-2018-7712"
    $wsDoc.Cells.Item($docStart + 1, 7).Value2 = "9811223306"
    $wsDoc.Cells.Item($docStart + 1, 8).Value2 = "ananya@apnaclinic.com"
    $wsDoc.Cells.Item($docStart + 1, 9).Value2 = "ROOM-000002"
    $wsDoc.Cells.Item($docStart + 1, 10).Value2 = 550.0
    $wsDoc.Cells.Item($docStart + 1, 11).Value2 = 15
    $wsDoc.Cells.Item($docStart + 1, 12).Value2 = "ACTIVE"
    $wsDoc.Cells.Item($docStart + 1, 13).Value2 = "2026-09-01"
    $wsDoc.Cells.Item($docStart + 1, 14).Value2 = "2026-09-01 09:00:00"
    $wsDoc.Cells.Item($docStart + 1, 15).Value2 = "2026-09-01 09:00:00"

    # 3. Insert 2 new appointments on business date 2026-09-29
    $wsApt = $wbTest.Sheets.Item("06_APPOINTMENTS")
    $aptStart = $wsApt.UsedRange.Rows.Count + 1
    $wsApt.Cells.Item($aptStart, 1).Value2 = "APT-000011"
    $wsApt.Cells.Item($aptStart, 2).Value2 = "APT-20260929-011"
    $wsApt.Cells.Item($aptStart, 3).Value2 = "PAT-000011"
    $wsApt.Cells.Item($aptStart, 4).Value2 = "DOC-000005"
    $wsApt.Cells.Item($aptStart, 5).Value2 = "2026-09-29"
    $wsApt.Cells.Item($aptStart, 6).Value2 = "14:00"
    $wsApt.Cells.Item($aptStart, 7).Value2 = "14:20"
    $wsApt.Cells.Item($aptStart, 8).Value2 = "NEW_CONSULTATION"
    $wsApt.Cells.Item($aptStart, 9).Value2 = "PHONE"
    $wsApt.Cells.Item($aptStart, 10).Value2 = "SCHEDULED"
    $wsApt.Cells.Item($aptStart, 11).Value2 = 11
    $wsApt.Cells.Item($aptStart, 12).Value2 = "ROOM-000001"
    $wsApt.Cells.Item($aptStart, 13).Value2 = "Chest tightness on exertion"
    $wsApt.Cells.Item($aptStart, 14).Value2 = "YES"
    $wsApt.Cells.Item($aptStart, 15).Value2 = "SENT"
    $wsApt.Cells.Item($aptStart, 16).Value2 = "2026-09-29 08:30:00"
    $wsApt.Cells.Item($aptStart, 17).Value2 = "2026-09-29 08:30:00"
    $wsApt.Cells.Item($aptStart, 18).Value2 = "USR-000002"
    $wsApt.Cells.Item($aptStart, 19).Value2 = "USR-000002"

    $wsApt.Cells.Item($aptStart + 1, 1).Value2 = "APT-000012"
    $wsApt.Cells.Item($aptStart + 1, 2).Value2 = "APT-20260929-012"
    $wsApt.Cells.Item($aptStart + 1, 3).Value2 = "PAT-000012"
    $wsApt.Cells.Item($aptStart + 1, 4).Value2 = "DOC-000006"
    $wsApt.Cells.Item($aptStart + 1, 5).Value2 = "2026-09-29"
    $wsApt.Cells.Item($aptStart + 1, 6).Value2 = "14:30"
    $wsApt.Cells.Item($aptStart + 1, 7).Value2 = "14:45"
    $wsApt.Cells.Item($aptStart + 1, 8).Value2 = "NEW_CONSULTATION"
    $wsApt.Cells.Item($aptStart + 1, 9).Value2 = "WALK_IN"
    $wsApt.Cells.Item($aptStart + 1, 10).Value2 = "IN_CONSULTATION"
    $wsApt.Cells.Item($aptStart + 1, 11).Value2 = 12
    $wsApt.Cells.Item($aptStart + 1, 12).Value2 = "ROOM-000002"
    $wsApt.Cells.Item($aptStart + 1, 13).Value2 = "Skin rash on forearm"
    $wsApt.Cells.Item($aptStart + 1, 14).Value2 = "YES"
    $wsApt.Cells.Item($aptStart + 1, 15).Value2 = "SENT"
    $wsApt.Cells.Item($aptStart + 1, 16).Value2 = "2026-09-29 09:00:00"
    $wsApt.Cells.Item($aptStart + 1, 17).Value2 = "2026-09-29 09:00:00"
    $wsApt.Cells.Item($aptStart + 1, 18).Value2 = "USR-000002"
    $wsApt.Cells.Item($aptStart + 1, 19).Value2 = "USR-000002"

    # 4. Insert 2 new queue tokens (1 WAITING, 1 IN_CONSULTATION)
    $wsQue = $wbTest.Sheets.Item("08_QUEUE")
    $queStart = $wsQue.UsedRange.Rows.Count + 1
    $wsQue.Cells.Item($queStart, 1).Value2 = "TOK-000011"
    $wsQue.Cells.Item($queStart, 2).Value2 = "APT-000011"
    $wsQue.Cells.Item($queStart, 3).Value2 = "PAT-000011"
    $wsQue.Cells.Item($queStart, 4).Value2 = "DOC-000005"
    $wsQue.Cells.Item($queStart, 5).Value2 = 11
    $wsQue.Cells.Item($queStart, 6).Value2 = "2026-09-29"
    $wsQue.Cells.Item($queStart, 7).Value2 = "13:50"
    $wsQue.Cells.Item($queStart, 8).Value2 = ""
    $wsQue.Cells.Item($queStart, 9).Value2 = ""
    $wsQue.Cells.Item($queStart, 10).Value2 = ""
    $wsQue.Cells.Item($queStart, 11).Value2 = "WAITING"
    $wsQue.Cells.Item($queStart, 12).Value2 = "NORMAL"
    $wsQue.Cells.Item($queStart, 13).Value2 = "ROOM-000001"
    $wsQue.Cells.Item($queStart, 14).Value2 = "2026-09-29 13:50:00"
    $wsQue.Cells.Item($queStart, 15).Value2 = "2026-09-29 13:50:00"

    $wsQue.Cells.Item($queStart + 1, 1).Value2 = "TOK-000012"
    $wsQue.Cells.Item($queStart + 1, 2).Value2 = "APT-000012"
    $wsQue.Cells.Item($queStart + 1, 3).Value2 = "PAT-000012"
    $wsQue.Cells.Item($queStart + 1, 4).Value2 = "DOC-000006"
    $wsQue.Cells.Item($queStart + 1, 5).Value2 = 12
    $wsQue.Cells.Item($queStart + 1, 6).Value2 = "2026-09-29"
    $wsQue.Cells.Item($queStart + 1, 7).Value2 = "14:15"
    $wsQue.Cells.Item($queStart + 1, 8).Value2 = "14:28"
    $wsQue.Cells.Item($queStart + 1, 9).Value2 = "14:30"
    $wsQue.Cells.Item($queStart + 1, 10).Value2 = ""
    $wsQue.Cells.Item($queStart + 1, 11).Value2 = "IN_CONSULTATION"
    $wsQue.Cells.Item($queStart + 1, 12).Value2 = "NORMAL"
    $wsQue.Cells.Item($queStart + 1, 13).Value2 = "ROOM-000002"
    $wsQue.Cells.Item($queStart + 1, 14).Value2 = "2026-09-29 14:15:00"
    $wsQue.Cells.Item($queStart + 1, 15).Value2 = "2026-09-29 14:30:00"

    # 5. Insert 1 new consultation
    $wsCon = $wbTest.Sheets.Item("09_CONSULTATIONS")
    $conStart = $wsCon.UsedRange.Rows.Count + 1
    $wsCon.Cells.Item($conStart, 1).Value2 = "CON-000006"
    $wsCon.Cells.Item($conStart, 2).Value2 = "APT-000011"
    $wsCon.Cells.Item($conStart, 3).Value2 = "PAT-000011"
    $wsCon.Cells.Item($conStart, 4).Value2 = "DOC-000005"
    $wsCon.Cells.Item($conStart, 5).Value2 = "Chest tightness on climbing stairs"
    $wsCon.Cells.Item($conStart, 6).Value2 = "Angina Pectoris / Ischemic Evaluation"
    $wsCon.Cells.Item($conStart, 7).Value2 = "135/88 mmHg"
    $wsCon.Cells.Item($conStart, 8).Value2 = "76 kg"
    $wsCon.Cells.Item($conStart, 9).Value2 = "98.4 F"
    $wsCon.Cells.Item($conStart, 10).Value2 = "Rest, ECG scheduled, avoid strenuous exertion"
    $wsCon.Cells.Item($conStart, 11).Value2 = "YES"
    $wsCon.Cells.Item($conStart, 12).Value2 = "2026-10-06"
    $wsCon.Cells.Item($conStart, 13).Value2 = "IN_PROGRESS"
    $wsCon.Cells.Item($conStart, 14).Value2 = "2026-09-29 14:02:00"
    $wsCon.Cells.Item($conStart, 15).Value2 = ""
    $wsCon.Cells.Item($conStart, 16).Value2 = "2026-09-29 14:02:00"
    $wsCon.Cells.Item($conStart, 17).Value2 = "2026-09-29 14:02:00"
    $wsCon.Cells.Item($conStart, 18).Value2 = "USR-000002"

    # 6. Insert 2 new prescriptions
    $wsRx = $wbTest.Sheets.Item("14_PRESCRIPTIONS")
    $rxStart = $wsRx.UsedRange.Rows.Count + 1
    $wsRx.Cells.Item($rxStart, 1).Value2 = "RX-000011"
    $wsRx.Cells.Item($rxStart, 2).Value2 = "CON-000006"
    $wsRx.Cells.Item($rxStart, 3).Value2 = "PAT-000011"
    $wsRx.Cells.Item($rxStart, 4).Value2 = "Sorbitrate 5mg"
    $wsRx.Cells.Item($rxStart, 5).Value2 = "TABLET"
    $wsRx.Cells.Item($rxStart, 6).Value2 = "5mg"
    $wsRx.Cells.Item($rxStart, 7).Value2 = "AS_NEEDED"
    $wsRx.Cells.Item($rxStart, 8).Value2 = "7_DAYS"
    $wsRx.Cells.Item($rxStart, 9).Value2 = "ORAL"
    $wsRx.Cells.Item($rxStart, 10).Value2 = "Sublingual under tongue during acute chest pain"
    $wsRx.Cells.Item($rxStart, 11).Value2 = 10
    $wsRx.Cells.Item($rxStart, 12).Value2 = "2026-09-29 14:10:00"

    $wsRx.Cells.Item($rxStart + 1, 1).Value2 = "RX-000012"
    $wsRx.Cells.Item($rxStart + 1, 2).Value2 = "CON-000006"
    $wsRx.Cells.Item($rxStart + 1, 3).Value2 = "PAT-000011"
    $wsRx.Cells.Item($rxStart + 1, 4).Value2 = "Atorvastatin 20mg"
    $wsRx.Cells.Item($rxStart + 1, 5).Value2 = "TABLET"
    $wsRx.Cells.Item($rxStart + 1, 6).Value2 = "20mg"
    $wsRx.Cells.Item($rxStart + 1, 7).Value2 = "ONCE_DAILY"
    $wsRx.Cells.Item($rxStart + 1, 8).Value2 = "30_DAYS"
    $wsRx.Cells.Item($rxStart + 1, 9).Value2 = "ORAL"
    $wsRx.Cells.Item($rxStart + 1, 10).Value2 = "Take at bedtime with water"
    $wsRx.Cells.Item($rxStart + 1, 11).Value2 = 30
    $wsRx.Cells.Item($rxStart + 1, 12).Value2 = "2026-09-29 14:10:00"

    # 7. Insert 1 new billing invoice with formula-driven total & due
    $wsBil = $wbTest.Sheets.Item("10_BILLING")
    $bilRow = $wsBil.UsedRange.Rows.Count + 1
    $wsBil.Cells.Item($bilRow, 1).Value2 = "INV-000006"
    $wsBil.Cells.Item($bilRow, 2).Value2 = "INV-20260929-006"
    $wsBil.Cells.Item($bilRow, 3).Value2 = "PAT-000011"
    $wsBil.Cells.Item($bilRow, 4).Value2 = "APT-000011"
    $wsBil.Cells.Item($bilRow, 5).Value2 = "2026-09-29"
    $wsBil.Cells.Item($bilRow, 6).Value2 = 700.0  # subtotal
    $wsBil.Cells.Item($bilRow, 7).Value2 = 50.0   # discount
    $wsBil.Cells.Item($bilRow, 8).Value2 = 35.0   # tax (5%)
    $wsBil.Cells.Item($bilRow, 9).Formula = "=F$bilRow-G$bilRow+H$bilRow" # total
    $wsBil.Cells.Item($bilRow, 10).Value2 = 685.0 # paid
    $wsBil.Cells.Item($bilRow, 11).Formula = "=I$bilRow-J$bilRow" # due
    $wsBil.Cells.Item($bilRow, 12).Value2 = "PAID"
    $wsBil.Cells.Item($bilRow, 13).Value2 = "2026-09-29 14:15:00"
    $wsBil.Cells.Item($bilRow, 14).Value2 = "2026-09-29 14:15:00"
    $wsBil.Cells.Item($bilRow, 15).Value2 = "USR-000002"

    # 8. Insert 1 new payment
    $wsPay = $wbTest.Sheets.Item("11_PAYMENTS")
    $payRow = $wsPay.UsedRange.Rows.Count + 1
    $wsPay.Cells.Item($payRow, 1).Value2 = "PAY-000006"
    $wsPay.Cells.Item($payRow, 2).Value2 = "INV-000006"
    $wsPay.Cells.Item($payRow, 3).Value2 = "PAT-000011"
    $wsPay.Cells.Item($payRow, 4).Value2 = "2026-09-29"
    $wsPay.Cells.Item($payRow, 5).Value2 = 685.0
    $wsPay.Cells.Item($payRow, 6).Value2 = "UPI"
    $wsPay.Cells.Item($payRow, 7).Value2 = "TXN-UPI-9908" # transaction_reference
    $wsPay.Cells.Item($payRow, 8).Value2 = "COMPLETED"    # payment_status
    $wsPay.Cells.Item($payRow, 9).Value2 = "USR-000002"
    $wsPay.Cells.Item($payRow, 10).Value2 = "UPI QR code counter settlement"
    $wsPay.Cells.Item($payRow, 11).Value2 = "2026-09-29 14:16:00"

    $results["test_flow_records_inserted"] = 12
    Write-Host "      Injected 12 realistic records into test workbook across 8 entities."

    # Force Recalculation on the test workbook
    Write-Host "      Recalculating test workbook in Excel engine..."
    $excel.CalculateFullRebuild()

    # Verify newly calculated invoice row in Excel
    $newInvTotal = [double]$wsBil.Cells.Item($bilRow, 9).Value2
    $newInvDue = [double]$wsBil.Cells.Item($bilRow, 11).Value2
    Write-Host "      New Invoice Calculated Total: $newInvTotal (Expected: 685.00)"
    Write-Host "      New Invoice Calculated Due:   $newInvDue (Expected: 0.00)"

    # Capture newly recalculated KPIs in 19_REPORTING
    $wsRepTest = $wbTest.Sheets.Item("19_REPORTING")
    $testKpis = @()
    for ($r = 2; $r -le 15; $r++) {
        $testKpis += @{
            "row" = $r
            "kpi_id" = [string]$wsRepTest.Cells.Item($r, 1).Text
            "metric_name" = [string]$wsRepTest.Cells.Item($r, 2).Text
            "formula" = [string]$wsRepTest.Cells.Item($r, 3).Formula
            "recalculated_value" = [string]$wsRepTest.Cells.Item($r, 3).Text
            "recalculated_numeric" = $wsRepTest.Cells.Item($r, 3).Value2
        }
    }
    $results["test_flow_recalculated_values"]["19_REPORTING"] = $testKpis
    $results["test_flow_recalculated_values"]["new_invoice"] = @{
        "total" = $newInvTotal
        "due" = $newInvDue
    }
    $results["test_flow_executed"] = $true

    $wbTest.Save()
    $wbTest.Close($false)
    $wbTest = $null

    $results["status"] = "COMPLETED"
    Write-Host "[SUCCESS] Excel Automation Execution Finished Successfully."

} catch {
    $results["status"] = "FAILED"
    $results["error"] = $_.Exception.Message
    Write-Host "[FATAL ERROR] $($_.Exception.Message)"
} finally {
    if ($null -ne $wb) { $wb.Close($false) }
    if ($null -ne $excel) {
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

$json = $results | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($jsonOutputFile, $json)
Write-Host "Exported Excel execution summary to: $jsonOutputFile"
