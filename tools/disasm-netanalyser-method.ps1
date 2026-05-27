param(
    [string]$TypeName = "WindowsApplication1.Network",
    [string]$MethodName = "Sendbtn_Click"
)

$ErrorActionPreference = "Stop"

if ([IntPtr]::Size -ne 4) {
    throw "Run this with 32-bit PowerShell."
}

$asmPath = "C:\Users\ezabz\Downloads\LINAnalyzer\NetworkAnalyser.exe"
$asm = [System.Reflection.Assembly]::LoadFrom($asmPath)
$type = $asm.GetType($TypeName)
$method = $type.GetMethod($MethodName, [System.Reflection.BindingFlags]"Public,NonPublic,Instance,Static")
if (-not $method) { throw "Method not found: $TypeName.$MethodName" }

$single = @{}
$multi = @{}
foreach ($field in [System.Reflection.Emit.OpCodes].GetFields([System.Reflection.BindingFlags]"Public,Static")) {
    $op = [System.Reflection.Emit.OpCode]$field.GetValue($null)
    $value = ([int]$op.Value) -band 0xffff
    if (($value -band 0xff00) -eq 0xfe00) { $multi[$value -band 0xff] = $op } else { $single[$value] = $op }
}
Write-Host "opcode map single=$($single.Count) multi=$($multi.Count) has72=$($single.ContainsKey(114))"

$module = $method.Module
$bytes = $method.GetMethodBody().GetILAsByteArray()
$i = 0
while ($i -lt $bytes.Length) {
    $offset = $i
    $code = $bytes[$i++]
    if ($code -eq 0xfe) { $op = $multi[[int]$bytes[$i++]] } else { $op = $single[[int]$code] }
    if ($null -eq $op) {
        "{0:X4}: UNKNOWN 0x{1:X2}" -f $offset, $code
        break
    }
    $operand = $null
    $token = $null
    switch ($op.OperandType) {
        "InlineNone" { }
        "ShortInlineI" { $operand = $bytes[$i]; $i += 1 }
        "InlineI" { $operand = [BitConverter]::ToInt32($bytes, $i); $i += 4 }
        "InlineI8" { $operand = [BitConverter]::ToInt64($bytes, $i); $i += 8 }
        "ShortInlineR" { $operand = [BitConverter]::ToSingle($bytes, $i); $i += 4 }
        "InlineR" { $operand = [BitConverter]::ToDouble($bytes, $i); $i += 8 }
        "ShortInlineBrTarget" { $delta = [int]$bytes[$i]; if ($delta -gt 127) { $delta -= 256 }; $i += 1; $operand = $i + $delta }
        "InlineBrTarget" { $delta = [BitConverter]::ToInt32($bytes, $i); $i += 4; $operand = $i + $delta }
        "InlineSwitch" { $count = [BitConverter]::ToInt32($bytes, $i); $i += 4; $base = $i + (4 * $count); $targets = @(); for ($s = 0; $s -lt $count; $s++) { $targets += $base + [BitConverter]::ToInt32($bytes, $i); $i += 4 }; $operand = ($targets -join ",") }
        "InlineString" { $token = [BitConverter]::ToInt32($bytes, $i); $i += 4; $operand = '"' + $module.ResolveString($token) + '"' }
        "InlineField" { $token = [BitConverter]::ToInt32($bytes, $i); $i += 4; try { $operand = $module.ResolveField($token) } catch { $operand = ("field 0x{0:X8}" -f $token) } }
        "InlineMethod" { $token = [BitConverter]::ToInt32($bytes, $i); $i += 4; try { $operand = $module.ResolveMethod($token) } catch { $operand = ("method 0x{0:X8}" -f $token) } }
        "InlineType" { $token = [BitConverter]::ToInt32($bytes, $i); $i += 4; try { $operand = $module.ResolveType($token) } catch { $operand = ("type 0x{0:X8}" -f $token) } }
        "InlineTok" { $token = [BitConverter]::ToInt32($bytes, $i); $i += 4; try { $operand = $module.ResolveMember($token) } catch { $operand = ("tok 0x{0:X8}" -f $token) } }
        "InlineSig" { $token = [BitConverter]::ToInt32($bytes, $i); $i += 4; $operand = ("sig 0x{0:X8}" -f $token) }
        "InlineVar" { $operand = [BitConverter]::ToUInt16($bytes, $i); $i += 2 }
        "ShortInlineVar" { $operand = $bytes[$i]; $i += 1 }
        default { throw "Unsupported operand type $($op.OperandType) for opcode $($op.Name) at 0x$($offset.ToString('X4'))" }
    }
    "{0:X4}: {1,-12} {2}" -f $offset, $op.Name, $operand
}