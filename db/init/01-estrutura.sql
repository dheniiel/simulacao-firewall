-- Estrutura e dados de exemplo da Ouvidoria Municipal
-- (executado automaticamente na primeira subida do MySQL)
SET NAMES utf8mb4;
USE ouvidoria;

CREATE TABLE manifestacoes (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  protocolo        VARCHAR(20)  NOT NULL UNIQUE,
  tipo             VARCHAR(20)  NOT NULL,   -- Reclamação, Sugestão, Elogio...
  assunto          VARCHAR(120) NOT NULL,
  secretaria       VARCHAR(80)  NOT NULL,
  status           VARCHAR(30)  NOT NULL,   -- Recebida, Em análise, Respondida...
  data_abertura    DATE         NOT NULL,
  prazo_resposta   DATE         NOT NULL,
  ultimo_andamento VARCHAR(255) NOT NULL
);

-- Dados fictícios (sem dados pessoais do cidadão)
INSERT INTO manifestacoes (protocolo, tipo, assunto, secretaria, status,
                           data_abertura, prazo_resposta, ultimo_andamento)
VALUES
  ('OUV-2026-0001', 'Reclamação', 'Buraco na Rua 7, Centro', 'Obras',
   'Em análise', '2026-09-20', '2026-10-20', 'Encaminhada para vistoria técnica.'),
  ('OUV-2026-0002', 'Solicitação', 'Poda de árvore na Praça Matriz', 'Meio Ambiente',
   'Recebida', '2026-10-01', '2026-10-31', 'Manifestação registrada e triada.'),
  ('OUV-2026-0003', 'Sugestão', 'Novo horário de ônibus escolar', 'Educação',
   'Respondida', '2026-08-15', '2026-09-14', 'Resposta enviada ao cidadão.'),
  ('OUV-2026-0004', 'Elogio', 'Atendimento na UBS Vila Nova', 'Saúde',
   'Encerrada', '2026-07-02', '2026-08-01', 'Elogio repassado à equipe.'),
  ('OUV-2026-0005', 'Reclamação', 'Iluminação pública apagada', 'Obras',
   'Em análise', '2026-10-05', '2026-11-04', 'Ordem de serviço aberta.');
