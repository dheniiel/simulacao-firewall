<?php
// Sistema interno da Ouvidoria (uso exclusivo da rede interna da prefeitura)
// Cadastra, altera, exclui e visualiza manifestações no banco da DMZ.
$msg = null;
$erro = null;

function e($v) { return htmlspecialchars((string) $v, ENT_QUOTES, 'UTF-8'); }

try {
    $pdo = new PDO(
        'mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME')
            . ';charset=utf8mb4',
        getenv('DB_USER'),
        getenv('DB_PASS'),
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 5]
    );

    $acao = $_POST['acao'] ?? '';
    $campos = ['tipo', 'assunto', 'secretaria', 'status', 'prazo_resposta', 'ultimo_andamento'];
    $dados = [];
    foreach ($campos as $c) {
        $dados[$c] = trim($_POST[$c] ?? '');
    }

    if ($acao === 'criar') {
        // Grava com protocolo provisório e depois gera OUV-AAAA-NNNN a partir do id
        // (o id nunca se repete, então um protocolo excluído não é reaproveitado)
        $stmt = $pdo->prepare(
            'INSERT INTO manifestacoes (protocolo, tipo, assunto, secretaria, status,
                 data_abertura, prazo_resposta, ultimo_andamento)
             VALUES (?, ?, ?, ?, ?, CURDATE(), ?, ?)'
        );
        $stmt->execute(['TMP-' . bin2hex(random_bytes(6)), $dados['tipo'], $dados['assunto'],
                        $dados['secretaria'], $dados['status'], $dados['prazo_resposta'],
                        $dados['ultimo_andamento']]);
        $id = (int) $pdo->lastInsertId();
        $protocolo = sprintf('OUV-%s-%04d', date('Y'), $id);
        $pdo->prepare('UPDATE manifestacoes SET protocolo = ? WHERE id = ?')
            ->execute([$protocolo, $id]);
        $msg = "Manifestação cadastrada: $protocolo";
    } elseif ($acao === 'atualizar' || $acao === 'excluir') {
        $protocolo = $_POST['protocolo'] ?? '';
        if ($acao === 'atualizar') {
            $stmt = $pdo->prepare(
                'UPDATE manifestacoes SET status = ?, prazo_resposta = ?, ultimo_andamento = ?
                  WHERE protocolo = ?'
            );
            $stmt->execute([$dados['status'], $dados['prazo_resposta'],
                            $dados['ultimo_andamento'], $protocolo]);
            $feito = 'atualizada';
        } else {
            $stmt = $pdo->prepare('DELETE FROM manifestacoes WHERE protocolo = ?');
            $stmt->execute([$protocolo]);
            $feito = 'excluída';
        }
        if ($stmt->rowCount() > 0) {
            $msg = "Manifestação $feito: $protocolo";
        } else {
            $erro = "Nenhuma alteração para o protocolo $protocolo.";
        }
    }

    $lista = $pdo->query('SELECT * FROM manifestacoes ORDER BY id DESC')->fetchAll();
} catch (PDOException $ex) {
    error_log($ex->getMessage());
    $erro = 'Erro ao acessar o banco de dados.';
    $lista = [];
}
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>Sistema Interno da Ouvidoria</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; color: #1f2937; }
    h1 { color: #1e3a8a; }
    table { border-collapse: collapse; width: 100%; font-size: 13px; }
    th, td { border: 1px solid #d1d5db; padding: 6px; text-align: left; }
    th { background: #1e3a8a; color: #fff; }
    form.linha { display: inline; }
    fieldset { margin-bottom: 20px; }
    .ok { color: #15803d; } .erro { color: #b91c1c; }
  </style>
</head>
<body>
  <h1>Sistema Interno da Ouvidoria</h1>
  <?php if ($msg): ?><p class="ok"><?= e($msg) ?></p><?php endif; ?>
  <?php if ($erro): ?><p class="erro"><?= e($erro) ?></p><?php endif; ?>

  <fieldset>
    <legend>Nova manifestação</legend>
    <form method="post">
      <input type="hidden" name="acao" value="criar">
      <select name="tipo">
        <option>Reclamação</option><option>Solicitação</option>
        <option>Sugestão</option><option>Elogio</option>
      </select>
      <input name="assunto" placeholder="Assunto" required maxlength="120">
      <input name="secretaria" placeholder="Secretaria" required maxlength="80">
      <select name="status"><option>Recebida</option><option>Em análise</option></select>
      <input type="date" name="prazo_resposta" required>
      <input name="ultimo_andamento" placeholder="Andamento" required maxlength="255">
      <button>Cadastrar</button>
    </form>
  </fieldset>

  <table>
    <tr><th>Protocolo</th><th>Tipo</th><th>Assunto</th><th>Secretaria</th>
        <th>Status / Prazo / Andamento</th><th>Excluir</th></tr>
    <?php foreach ($lista as $m): ?>
    <tr>
      <td><?= e($m['protocolo']) ?></td>
      <td><?= e($m['tipo']) ?></td>
      <td><?= e($m['assunto']) ?></td>
      <td><?= e($m['secretaria']) ?></td>
      <td>
        <form method="post" class="linha">
          <input type="hidden" name="acao" value="atualizar">
          <input type="hidden" name="protocolo" value="<?= e($m['protocolo']) ?>">
          <select name="status">
            <?php foreach (['Recebida', 'Em análise', 'Respondida', 'Encerrada'] as $s): ?>
              <option <?= $s === $m['status'] ? 'selected' : '' ?>><?= e($s) ?></option>
            <?php endforeach; ?>
          </select>
          <input type="date" name="prazo_resposta" value="<?= e($m['prazo_resposta']) ?>">
          <input name="ultimo_andamento" value="<?= e($m['ultimo_andamento']) ?>" size="30">
          <button>Salvar</button>
        </form>
      </td>
      <td>
        <form method="post" class="linha" onsubmit="return confirm('Excluir?')">
          <input type="hidden" name="acao" value="excluir">
          <input type="hidden" name="protocolo" value="<?= e($m['protocolo']) ?>">
          <button>Excluir</button>
        </form>
      </td>
    </tr>
    <?php endforeach; ?>
  </table>
</body>
</html>
