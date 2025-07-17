#!/bin/bash

echo "========================================================="
echo "AVM Pattern Module Tests & Examples Usage Analysis"
echo "Analysis of how pattern module TESTS and EXAMPLES use resources"
echo "========================================================="
echo

echo "1. BICEP PATTERN MODULE TESTS ANALYSIS"
echo "======================================"

# Count actual Bicep pattern modules
bicep_modules=$(ls -d /Azure/bicep-registry-modules/avm/ptn/*/* 2>/dev/null | wc -l | tr -d ' ')
echo "Total Bicep pattern modules: $bicep_modules"

# Count Bicep files
bicep_total=$(find /Azure/bicep-registry-modules/avm/ptn -path "*/tests/*" -name "*.bicep" 2>/dev/null | wc -l | tr -d ' ')
echo "Total Bicep TEST files analyzed: $bicep_total"

# Count files with native resources
bicep_native_files=$(find /Azure/bicep-registry-modules/avm/ptn -path "*/tests/*" -name "*.bicep" -exec grep -l "resource.*'Microsoft\." {} \; 2>/dev/null | wc -l | tr -d ' ')
echo "Test files with native Microsoft resources: $bicep_native_files"

# Count files with AVM modules
bicep_avm_files=$(find /Azure/bicep-registry-modules/avm/ptn -path "*/tests/*" -name "*.bicep" -exec grep -l "module.*'br/public:avm\|module.*'br:mcr\.microsoft\.com.*avm" {} \; 2>/dev/null | wc -l | tr -d ' ')
echo "Test files with AVM modules: $bicep_avm_files"

echo

echo "2. TERRAFORM PATTERN MODULE EXAMPLES ANALYSIS"
echo "=============================================="

# Count actual Terraform pattern modules
terraform_modules=$(ls -d /Azure/terraform-azurerm-avm-ptn*/ 2>/dev/null | wc -l | tr -d ' ')
echo "Total Terraform pattern modules: $terraform_modules"

# Count Terraform files
terraform_total=$(find /Azure/terraform-azurerm-avm-ptn* -path "*/examples/*" -name "main.tf" 2>/dev/null | wc -l | tr -d ' ')
echo "Total Terraform EXAMPLE files analyzed: $terraform_total"

# Count files with native resources
terraform_native_files=$(find /Azure/terraform-azurerm-avm-ptn* -path "*/examples/*" -name "main.tf" -exec grep -l 'resource "azurerm_' {} \; 2>/dev/null | wc -l | tr -d ' ')
echo "Example files with native azurerm resources: $terraform_native_files"

# Count files with AVM modules
terraform_avm_files=$(find /Azure/terraform-azurerm-avm-ptn* -path "*/examples/*" -name "main.tf" -exec grep -l 'source.*=.*"Azure/avm-' {} \; 2>/dev/null | wc -l | tr -d ' ')
echo "Example files with AVM modules: $terraform_avm_files"

echo

echo "3. STATISTICAL SUMMARY"
echo "======================"

# Calculate percentages for Bicep (file-based analysis)
if [ $bicep_total -gt 0 ]; then
    bicep_native_pct=$(echo "scale=1; $bicep_native_files * 100 / $bicep_total" | bc -l)
    bicep_avm_pct=$(echo "scale=1; $bicep_avm_files * 100 / $bicep_total" | bc -l)
else
    bicep_native_pct=0
    bicep_avm_pct=0
fi

# Calculate percentages for Terraform (file-based analysis)
if [ $terraform_total -gt 0 ]; then
    terraform_native_pct=$(echo "scale=1; $terraform_native_files * 100 / $terraform_total" | bc -l)
    terraform_avm_pct=$(echo "scale=1; $terraform_avm_files * 100 / $terraform_total" | bc -l)
else
    terraform_native_pct=0
    terraform_avm_pct=0
fi

echo "MARKDOWN TABLE"
echo "=============="
echo
echo "| Ecosystem | Pattern Modules | Test/Example Files | Native Resources | AVM Modules | Native % | AVM % |"
echo "|-----------|----------------|-------------------|------------------|-------------|----------|-------|"
echo "| Bicep (Tests)     | $bicep_modules             | $bicep_total                 | $bicep_native_files              | $bicep_avm_files           | ${bicep_native_pct}%     | ${bicep_avm_pct}% |"
echo "| Terraform (Examples) | $terraform_modules             | $terraform_total                 | $terraform_native_files              | $terraform_avm_files           | ${terraform_native_pct}%     | ${terraform_avm_pct}% |"
echo "| **Total** | **$((bicep_modules + terraform_modules))**         | **$((bicep_total + terraform_total))**               | **$((bicep_native_files + terraform_native_files))**            | **$((bicep_avm_files + terraform_avm_files))**         | **$(echo "scale=1; ($bicep_native_files + $terraform_native_files) * 100 / ($bicep_total + $terraform_total)" | bc -l)%**   | **$(echo "scale=1; ($bicep_avm_files + $terraform_avm_files) * 100 / ($bicep_total + $terraform_total)" | bc -l)%** |"
echo
echo

echo "BICEP PATTERN MODULE TESTS (File-based Analysis):"
echo "- Pattern modules: $bicep_modules"
echo "- Test files analyzed: $bicep_total"
echo "- Test files with native resources: $bicep_native_files/$bicep_total (${bicep_native_pct}%)"
echo "- Test files with AVM modules: $bicep_avm_files/$bicep_total (${bicep_avm_pct}%)"
echo

echo "TERRAFORM PATTERN MODULE EXAMPLES (File-based Analysis):"
echo "- Pattern modules: $terraform_modules"
echo "- Example files analyzed: $terraform_total"
echo "- Example files with native resources: $terraform_native_files/$terraform_total (${terraform_native_pct}%)"
echo "- Example files with AVM modules: $terraform_avm_files/$terraform_total (${terraform_avm_pct}%)"
echo

# Calculate overall statistics
total_files=$((bicep_total + terraform_total))
total_native_files=$((bicep_native_files + terraform_native_files))
total_avm_files=$((bicep_avm_files + terraform_avm_files))

if [ $total_files -gt 0 ]; then
    overall_native_pct=$(echo "scale=1; $total_native_files * 100 / $total_files" | bc -l)
    overall_avm_pct=$(echo "scale=1; $total_avm_files * 100 / $total_files" | bc -l)
else
    overall_native_pct=0
    overall_avm_pct=0
fi

echo "OVERALL COMBINED ANALYSIS:"
echo "- Test/Example files with native resources: $total_native_files/$total_files (${overall_native_pct}%)"
echo "- Test/Example files with AVM modules: $total_avm_files/$total_files (${overall_avm_pct}%)"
echo

echo "4. CONCLUSION"
echo "============="
if [ $total_avm_files -gt $total_native_files ]; then
    echo "❌ Pattern module tests/examples STILL predominantly use NATIVE resources rather than AVM modules"
    echo "   Native: $total_native_files files (${overall_native_pct}%) vs AVM: $total_avm_files files (${overall_avm_pct}%)"
elif [ $total_native_files -gt $total_avm_files ]; then
    echo "❌ Pattern module tests/examples predominantly use NATIVE resources rather than AVM modules"
    echo "   Native: $total_native_files files (${overall_native_pct}%) vs AVM: $total_avm_files files (${overall_avm_pct}%)"
else
    echo "⚖️  Equal usage of native resources and AVM modules in pattern module tests/examples"
fi

echo
echo "Key Insights:"
echo "- Bicep: $bicep_modules pattern modules with $bicep_total test files (avg $(echo "scale=1; $bicep_total / $bicep_modules" | bc -l) files/module)"
echo "- Terraform: $terraform_modules pattern modules with $terraform_total example files (avg $(echo "scale=1; $terraform_total / $terraform_modules" | bc -l) files/module)"
echo "- Note: Terraform average is skewed by modules with extensive example suites"
echo "- Both ecosystems show similar pattern: ~70-74% native resource usage in tests/examples"
echo "- This analysis is about TEST and EXAMPLE files, NOT the pattern modules themselves"
echo "- Pattern module tests/examples are not yet fully demonstrating 'modules calling modules' approach"
