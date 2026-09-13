<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>Prueba OKD Tekton + CI/CD</title>
  <style>
    body { font-family: sans-serif; background: #0f172a; color: #f8fafc; text-align: center; padding: 50px; }
    .card { background: #1e293b; padding: 30px; border-radius: 12px; display: inline-block; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.5); }
    h1 { color: #38bdf8; }
    .badge { background: #10b981; color: white; padding: 6px 12px; border-radius: 6px; font-weight: bold; }
    .meta { color: #94a3b8; font-size: 0.9em; margin-top: 15px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Aplicación PHP compilada con Tekton</h1>
    <p><span class="badge">ESTADO: MOTOR CI/CD OPERATIVO</span></p>
    <p><strong>Host / Pod:</strong> <?php echo gethostname(); ?></p>
    <p><strong>Fecha/Hora servidor:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
    <p><strong>Versión PHP:</strong> <?php echo phpversion(); ?></p>
    <p><strong>Origen:</strong> GitHub (oscarmash/testing)</p>
  </div>
</body>
</html>
