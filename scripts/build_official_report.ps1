param(
  [string]$Template = 'docs/report/official-submission-template.docx',
  [string]$Content = 'docs/report/template-content.json'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$data = Get-Content -Raw -Encoding utf8 -LiteralPath $Content | ConvertFrom-Json
$evidence = Get-Content -Raw -LiteralPath 'docs/verification/2026-09-16/summary.json' | ConvertFrom-Json
$work = Join-Path $root ('submission/template-work-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $work | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path -LiteralPath $Template).Path, $work)
$xmlPath = Join-Path $work 'word/document.xml'
[xml]$xml = Get-Content -Raw -LiteralPath $xmlPath
$w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$ns = [Xml.XmlNamespaceManager]::new($xml.NameTable)
$ns.AddNamespace('w', $w)
$body = $xml.SelectSingleNode('//w:body', $ns)
$original = @($body.ChildNodes | ForEach-Object { $_.CloneNode($true) })
function New-Element([string]$name) { return $xml.CreateElement('w', $name, $w) }
function Set-Attribute($node,[string]$name,[string]$value) { [void]$node.SetAttribute($name, $w, $value) }
function New-Paragraph([string]$text, [string]$kind = 'body') {
  $p = New-Element 'p'
  $pp = New-Element 'pPr'
  $spacing = New-Element 'spacing'
  Set-Attribute $spacing 'after' '90'
  Set-Attribute $spacing 'line' '276'
  Set-Attribute $spacing 'lineRule' 'auto'
  [void]$pp.AppendChild($spacing)
  if ($kind -eq 'label') { [void]$pp.AppendChild((New-Element 'keepNext')) }
  [void]$p.AppendChild($pp)
  $r = New-Element 'r'
  $rp = New-Element 'rPr'
  if ($kind -eq 'label') { [void]$rp.AppendChild((New-Element 'b')) }
  [void]$r.AppendChild($rp)
  $t = New-Element 't'; $t.InnerText = $text
  [void]$r.AppendChild($t); [void]$p.AppendChild($r)
  return $p
}
function Add-Paragraph([string]$text, [string]$kind = 'body') {
  [void]$body.AppendChild((New-Paragraph $text $kind))
}
function Fill-Cell($cell,[string]$text) {
  foreach($child in @($cell.ChildNodes)) { if($child.LocalName -ne 'tcPr'){ [void]$cell.RemoveChild($child) } }
  [void]$cell.AppendChild((New-Paragraph $text))
}
function Add-Table([string[]]$rows) {
  $tbl = New-Element 'tbl'
  $pr = New-Element 'tblPr'
  $width = New-Element 'tblW'; Set-Attribute $width 'w' '9000'; Set-Attribute $width 'type' 'dxa'; [void]$pr.AppendChild($width)
  $borders = New-Element 'tblBorders'
  foreach($edge in @('top','left','bottom','right','insideH','insideV')) {
    $b = New-Element $edge; Set-Attribute $b 'val' 'single'; Set-Attribute $b 'sz' '4'; Set-Attribute $b 'color' 'CEDCDF'; [void]$borders.AppendChild($b)
  }
  [void]$pr.AppendChild($borders); [void]$tbl.AppendChild($pr)
  $sizes = @(2100,2350,4550)
  $grid = New-Element 'tblGrid'
  foreach($size in $sizes){$g=New-Element 'gridCol'; Set-Attribute $g 'w' "$size"; [void]$grid.AppendChild($g)}
  [void]$tbl.AppendChild($grid)
  for($i=0;$i -lt $rows.Count;$i++){
    $row=New-Element 'tr'; $trp=New-Element 'trPr'; [void]$trp.AppendChild((New-Element 'cantSplit'))
    if($i -eq 0){[void]$trp.AppendChild((New-Element 'tblHeader'))}
    [void]$row.AppendChild($trp)
    $cells=$rows[$i].Split('|')
    for($j=0;$j -lt $cells.Count;$j++){
      $cell=New-Element 'tc';$cp=New-Element 'tcPr';$cw=New-Element 'tcW'
      Set-Attribute $cw 'w' "$($sizes[$j])";Set-Attribute $cw 'type' 'dxa';[void]$cp.AppendChild($cw)
      if($i -eq 0){$shade=New-Element 'shd';Set-Attribute $shade 'fill' 'E4EFF1';Set-Attribute $shade 'val' 'clear';[void]$cp.AppendChild($shade)}
      [void]$cell.AppendChild($cp)
      [void]$cell.AppendChild((New-Paragraph $cells[$j] $(if($i -eq 0){'label'}else{'body'})))
      [void]$row.AppendChild($cell)
    }
    [void]$tbl.AppendChild($row)
  }
  [void]$body.AppendChild($tbl)
  Add-Paragraph ''
}
$mapping = @{
  10=@('','abstract'); 13=@('项目背景与问题定义','background'); 14=@('技术难点','challenges'); 15=@('创新点','innovation')
  17=@('系统总体架构','architecture');18=@('方案论证与选型','selection');19=@('关键模块设计','modules')
  21=@('AI 算法实现','ai');22=@('关键机制设计','mechanisms');23=@('openvela 系统能力的深度运用','platform')
  25=@('软件 / 固件架构','software');26=@('数据流与关键流程设计','flow');27=@('硬件设计与适配','hardware')
  28=@('应用 / 交互端设计','ui');29=@('自定义 Skill','skill')
  31=@('测试环境','environment');32=@('功能测试','functional');33=@('性能测试','performance');34=@('可靠性与稳定性测试','reliability')
  37=@('AI 工具的作用与开发中遇到的问题','ai_development')
  39=@('成果总结','conclusion');40=@('应用前景与商业价值','value');41=@('不足与未来工作','future')
}
$body.RemoveAll()
Add-Paragraph '2026 首届 openvela AI 硬件开发者大赛 · 技术报告' 'label'
Add-Paragraph 'FocusLoop｜把零散的时光，织成记忆的回响。' 'label'
Add-Paragraph '博丽灵梦赛高 · 龚城立　　版本：2026-09-16'
for($i=7;$i -le 41;$i++){
  if($i -eq 8){
    $tbl=$original[$i];$rows=$tbl.SelectNodes('w:tr',$ns)
    $values=@('FocusLoop（腕上主动学习闭环）','博丽灵梦赛高（253）','龚城立：产品定义、系统集成、测试验收与作品展示','手表应用创新；AI 硬件产品创新')
    for($k=1;$k -le 4;$k++){Fill-Cell $rows[$k].SelectNodes('w:tc',$ns)[1] $values[$k-1]}
    [void]$body.AppendChild($tbl)
  } elseif($i -eq 36){
    $tbl=$original[$i];$rows=$tbl.SelectNodes('w:tr',$ns)
    $values=@(
      '约 50%。参赛者按新增及修改代码估算，未作逐行归因统计。',
      'Codex、Claude Code（MiMo）。DeepSeek 辅助本次报告润色。',
      '未使用 VelaJS MCP；开发与联调使用 Shell、ADB 及官方文档。',
      '自建运行时 FocusLoop Skill，以及开发侧 focusloop-verify Skill。',
      'MiMo：本项目用量 2,193,625,712+ Token；GPT 用量未单独统计。'
    )
    for($k=1;$k -le 5;$k++){Fill-Cell $rows[$k].SelectNodes('w:tc',$ns)[1] $values[$k-1]}
    [void]$body.AppendChild($tbl)
  } elseif($mapping.ContainsKey($i)){
    $m=$mapping[$i]; if($m[0]){Add-Paragraph $m[0] 'label'}
    foreach($p in ($data.($m[1]) -split '\r?\n')){Add-Paragraph $p}
    if($i -eq 17){Add-Paragraph '[[ARCHITECTURE]]';Add-Paragraph '图 1　内容生成、端侧计算与 Agent 执行的数据流。'}
    if($i -eq 19){
      Add-Table @(
        "模块|输入与输出|源码入口",
        "内容规范化|模型文本 → 题卡对象|agent_protocol.js：extractPayload / normalizePlan",
        "间隔调度|答题结果 → dueAt|scheduler.js：gradeCard / nextDueCard",
        "情境判断|压力、采样、到期 → ready|context.js：evaluateReviewWindow",
        "事件与存储|设备订阅、偏好 → 本地状态|context_monitor.js / store.js"
      )
      Add-Paragraph '上述文件均位于 quickapp/focusloop/src/common/。'
    }
    if($i -eq 22){
      Add-Paragraph '计算示例：已开启推荐、完成首次学习，题卡将在 20 分钟后到期，静止采样充足且冷却结束。初始压力阈值为 25。'
      Add-Table @(
        '输入或操作|结果|计算依据',
        '当前压力 22|进入可推荐状态|22 ≤ 25，其余条件均满足',
        '此时选择“稍后”|阈值更新为 24|目标值 min(25, 22−2)=20；round(25×0.8+20×0.2)=24'
      )
    }
    if($i -eq 26){Add-Paragraph '[[FLOW]]';Add-Paragraph '图 2　学习进度先保存，定时任务失败后可重试。'}
    if($i -eq 28){Add-Paragraph '[[UI]]';Add-Paragraph '图 3　Goldfish 实际运行画面：学习首页、专注、答题、结果。'}
    if($i -eq 33){
      $testTimes=@($evidence.runs | Where-Object name -like 'test-*' | ForEach-Object elapsedMs)
      $buildTimes=@($evidence.runs | Where-Object name -like 'build-*' | ForEach-Object elapsedMs)
      $testMean=[math]::Round(($testTimes | Measure-Object -Average).Average)
      $buildMean=[math]::Round(($buildTimes | Measure-Object -Average).Average)
      Add-Table @(
        "测试项|本轮结果|证据 / 测量范围",
        "功能与集成约束|28 项 × 20 轮 = 560 项通过|test-01.txt 至 test-20.txt；纯函数和源码约束",
        "测试进程耗时|平均 $testMean ms；最大 $(($testTimes|Measure-Object -Maximum).Maximum) ms|含 Node 进程启动，非设备耗时",
        "连续构建|5 / 5 成功；平均 $buildMean ms|build-1.txt 至 build-5.txt；宿主机构建",
        "生产依赖审计|0 个漏洞|audit-production.txt；不含开发依赖",
        "参赛 RPK|72,703 字节|artifacts/ 中原参赛制品与 SHA-256",
        "设备性能|未测量|模型延迟、功耗、ASR 准确率、内存"
      )
      Add-Paragraph '证据目录：docs/verification/2026-09-16/。summary.json 记录命令、退出码、用时及输出哈希；复测命令：node scripts/collect_verification.cjs。'
    }
  } else {
    $p=$original[$i]
    if($i -in @(16,20,24,30,35)){
      $pp=$p.SelectSingleNode('w:pPr',$ns)
      if(-not $pp){$pp=New-Element 'pPr';[void]$p.PrependChild($pp)}
      [void]$pp.AppendChild((New-Element 'pageBreakBefore'))
    }
    [void]$body.AppendChild($p)
  }
}
Add-Paragraph '项目仓库：https://github.com/open-vela/contest2026_253_bolilingmengsaigao'
Add-Paragraph '目标分支：dev-ai-contest-2026。报告依据：官方《作品提交模板》1、2、3.1–3.7。'
$section=$original[51]
foreach($ref in @($section.SelectNodes('w:headerReference|w:footerReference',$ns))){[void]$section.RemoveChild($ref)}
[void]$body.AppendChild($section)
$xml.Save($xmlPath)
$corePath=Join-Path $work 'docProps/core.xml'
[xml]$core=Get-Content -Raw -LiteralPath $corePath
foreach($item in @(@('title','FocusLoop 技术报告'),@('creator','龚城立'),@('lastModifiedBy','龚城立'))){
  $node=$core.SelectSingleNode("//*[local-name()='$($item[0])']")
  if($node){$node.InnerText=$item[1]}
}
$core.Save($corePath)
$workingDocx=Join-Path $root 'submission/FocusLoop_官方模板_工作稿.docx'
if(Test-Path -LiteralPath $workingDocx){
  Move-Item -LiteralPath $workingDocx -Destination ($work + '-previous.docx')
}
[IO.Compression.ZipFile]::CreateFromDirectory($work,$workingDocx)
$word=$null;$doc=$null
try {
  $word=New-Object -ComObject Word.Application
  $word.Visible=$false;$word.DisplayAlerts=0
  $doc=$word.Documents.Open($workingDocx,$false,$false)
  $doc.Content.Font.Name='Calibri'
  $doc.Content.Font.NameFarEast='微软雅黑'
  $doc.Content.Font.Size=10.5
  $doc.Content.ParagraphFormat.SpaceAfter=4.5
  $doc.Content.ParagraphFormat.LineSpacingRule=0
  $doc.PageSetup.TopMargin=42.5;$doc.PageSetup.BottomMargin=42.5
  $doc.PageSetup.LeftMargin=42.5;$doc.PageSetup.RightMargin=42.5
  foreach($p in $doc.Paragraphs){
    $text=$p.Range.Text.Trim()
    if($text -match '^3\.[1-7]\s'){
      $p.Range.Font.Size=14;$p.Range.Font.Bold=1;$p.Range.Font.Color=4733718
      $p.SpaceBefore=8;$p.SpaceAfter=8;$p.KeepWithNext=-1
    } elseif($text -match '^[123]、'){
      $p.Range.Font.Size=12;$p.Range.Font.Bold=1;$p.KeepWithNext=-1
    }
  }
  $doc.Paragraphs.Item(1).Range.Font.Size=15
  $doc.Paragraphs.Item(2).Range.Font.Size=13
  $doc.Paragraphs.Item(2).Range.Font.Color=8354898
  foreach($table in $doc.Tables){
    $table.AllowAutoFit=$false
    $table.Rows.AllowBreakAcrossPages=0
    $table.Range.Font.Size=9.5
    $table.TopPadding=4;$table.BottomPadding=4
    $table.Rows.Item(1).Range.Font.Bold=1
  }
  $images=@{
    '[[ARCHITECTURE]]'=@('docs/report/architecture.svg',485)
    '[[FLOW]]'=@('docs/report/learning-flow.svg',440)
    '[[UI]]'=@('docs/report/goldfish-flow.png',440)
  }
  foreach($marker in $images.Keys){
    $range=$doc.Content.Duplicate
    if($range.Find.Execute($marker)){
      $range.Text=''
      $shape=$doc.InlineShapes.AddPicture((Join-Path $root $images[$marker][0]),$false,$true,$range)
      $shape.LockAspectRatio=-1;$shape.Width=$images[$marker][1]
    } else {throw "Missing image marker $marker"}
  }
  $footer=$doc.Sections.Item(1).Footers.Item(1).Range
  $footer.Text='FocusLoop · 博丽灵梦赛高　　'
  $footer.Font.Size=8;$footer.ParagraphFormat.Alignment=2
  $footer.Collapse(0);[void]$footer.Fields.Add($footer,33)
  $doc.Save()
  $pdf=Join-Path $root 'docs/FocusLoop_Project_Report.pdf'
  $doc.ExportAsFixedFormat($pdf,17)
  Write-Output "Official-template report exported: $pdf"
  Write-Output "Pages: $($doc.ComputeStatistics(2))"
} finally {
  if($doc){$doc.Close(0);[void][Runtime.InteropServices.Marshal]::ReleaseComObject($doc)}
  if($word){$word.Quit();[void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)}
}
