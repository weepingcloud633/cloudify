param([string]$Out)
# Cloudify icon: a white cartoon cloud with a heavy black outline and a grey underside,
# on a transparent background (no plate). Drawn from circles so it scales cleanly.
Add-Type -AssemblyName System.Drawing
$S = 1024
# the cloud as circles: cx, cy, r (in a 740 x 740 sketch space)
$circles = @(
    @(458, 255, 108), @(285, 305, 72), @(160, 385, 76), @(232, 432, 64), @(330, 402, 96),
    @(440, 430, 96), @(545, 432, 84), @(612, 420, 54), @(385, 458, 74), @(505, 468, 58)
)
function Master {
    $bmp = New-Object System.Drawing.Bitmap $S, $S
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)
    # fit the sketch (x 60..680, y 165..575) into the canvas with a small margin
    $k = 1.5; $ox = 512 - 370 * $k; $oy = 512 - 370 * $k
    function Fill($dy, $grow, $color) {
        $br = New-Object System.Drawing.SolidBrush $color
        foreach ($c in $circles) {
            $r = ($c[2] + $grow) * $k
            $g.FillEllipse($br, $ox + $c[0] * $k - $r, $oy + ($c[1] + $dy) * $k - $r, 2 * $r, 2 * $r)
        }
    }
    Fill 12 34 ([System.Drawing.Color]::FromArgb(255, 10, 10, 10))      # heavy outline all round, a little thicker underneath
    Fill 18 4 ([System.Drawing.Color]::FromArgb(255, 205, 205, 205))    # grey underside
    Fill 0 0 ([System.Drawing.Color]::FromArgb(255, 255, 255, 255))     # white body
    # inner puff outlines
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 10, 10, 10)), 20
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    function Arc($cx, $cy, $r, $a0, $sw) {
        $g.DrawArc($pen, $ox + ($cx - $r) * $k, $oy + ($cy - $r) * $k, 2 * $r * $k, 2 * $r * $k, $a0, $sw)
    }
    Arc 395 440 68 195 150
    Arc 505 440 36 195 120
    Arc 250 335 46 185 90
    # soft grey shading inside the big top puff, lower right
    $gp = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 200, 200, 200)), 22
    $gp.StartCap = 'Round'; $gp.EndCap = 'Round'
    $g.DrawArc($gp, $ox + (458 - 92) * $k, $oy + (255 - 92) * $k, 184 * $k, 184 * $k, 20, 70)
    $g.Dispose(); return $bmp
}
function Sized($master, $s) {
    $b = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.SmoothingMode = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($master, 0, 0, $s, $s); $g.Dispose(); return $b
}
$master = Master
$sizes = 16, 24, 32, 48, 64, 128, 256
$ms = New-Object System.IO.MemoryStream; $bw = New-Object System.IO.BinaryWriter $ms
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$blobs = @()
foreach ($s in $sizes) {
    $b = Sized $master $s
    $pm = New-Object System.IO.MemoryStream; $b.Save($pm, [System.Drawing.Imaging.ImageFormat]::Png); $blobs += , $pm.ToArray()
    if ($s -eq 256) { $b.Save((Join-Path (Split-Path $Out) 'icon-256.png'), [System.Drawing.Imaging.ImageFormat]::Png) }
    $b.Dispose()
}
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $dim = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$blobs[$i].Length); $bw.Write([uint32]$offset)
    $offset += $blobs[$i].Length
}
foreach ($bl in $blobs) { $bw.Write($bl) }
$bw.Flush(); [System.IO.File]::WriteAllBytes($Out, $ms.ToArray())
"wrote $Out"
