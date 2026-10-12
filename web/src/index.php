<?php
// Portal da Ouvidoria Municipal - consulta pública (somente leitura)
$protocolo = trim($_GET['protocolo'] ?? '');
$resultado = null;
$erro = null;

if ($protocolo !== '') {
    try {
        $pdo = new PDO(
            'mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME')
                . ';charset=utf8mb4',
            getenv('DB_USER'),
            getenv('DB_PASS'),
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 5]
        );
        // Consulta parametrizada (evita SQL Injection)
        $stmt = $pdo->prepare(
            'SELECT protocolo, tipo, assunto, secretaria, status, data_abertura,
                    prazo_resposta, ultimo_andamento
               FROM manifestacoes WHERE protocolo = ?'
        );
        $stmt->execute([$protocolo]);
        $resultado = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$resultado) {
            $erro = 'Protocolo não encontrado.';
        }
    } catch (PDOException $e) {
        error_log($e->getMessage());               // detalhe só no log do servidor
        $erro = 'Serviço temporariamente indisponível.';
    }
}

function e($v) { return htmlspecialchars((string) $v, ENT_QUOTES, 'UTF-8'); }
function data_br($d) { return date('d/m/Y', strtotime($d)); }
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>Ouvidoria Municipal - Consulta de Manifestação</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 640px; margin: 40px auto;
           padding: 0 16px; color: #1f2937; }
    h1 { color: #14532d; }
    form { display: flex; gap: 8px; margin: 20px 0; }
    input { flex: 1; padding: 8px; }
    button { padding: 8px 16px; background: #15803d; color: #fff; border: 0; }
    table { border-collapse: collapse; width: 100%; }
    td { border: 1px solid #d1d5db; padding: 8px; }
    td:first-child { font-weight: bold; width: 40%; background: #f3f4f6; }
    .erro { color: #b91c1c; }
  </style>
</head>
<body>
  <h1>Ouvidoria Municipal</h1>
  <p>Acompanhe o andamento e o prazo da sua manifestação.</p>

  <form method="get">
    <input name="protocolo" placeholder="Ex.: OUV-2026-0001" maxlength="20"
           value="<?= e($protocolo) ?>">
    <button type="submit">Consultar</button>
  </form>

  <?php if ($erro): ?>
    <p class="erro"><?= e($erro) ?></p>
  <?php elseif ($resultado): ?>
    <table>
      <tr><td>Protocolo</td><td><?= e($resultado['protocolo']) ?></td></tr>
      <tr><td>Tipo</td><td><?= e($resultado['tipo']) ?></td></tr>
      <tr><td>Assunto</td><td><?= e($resultado['assunto']) ?></td></tr>
      <tr><td>Secretaria</td><td><?= e($resultado['secretaria']) ?></td></tr>
      <tr><td>Status</td><td>Status: <?= e($resultado['status']) ?></td></tr>
      <tr><td>Aberta em</td><td><?= data_br($resultado['data_abertura']) ?></td></tr>
      <tr><td>Prazo de resposta</td>
          <td>Prazo: <?= data_br($resultado['prazo_resposta']) ?></td></tr>
      <tr><td>Último andamento</td><td><?= e($resultado['ultimo_andamento']) ?></td></tr>
    </table>
  <?php endif; ?>
</body>
</html>
