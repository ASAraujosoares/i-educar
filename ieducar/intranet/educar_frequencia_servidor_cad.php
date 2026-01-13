<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

return new class extends clsCadastro
{
    // --- PROPRIEDADES ---
    public $id;
    public $pessoa_logada;
    public $ref_cod_instituicao;
    public $ref_cod_escola;
    public $ano;
    public $mes;
    public $observacoes;

    public $servidores = [];
    public $frequencia_servidores = [];
    public $titulo;

    public $url_cancelar;
    public $nome_url_cancelar;

    public function Formular()
    {
        $this->titulo = 'Registro de Frequência de Servidores';
        $this->processoAp = 999888;
    }

    public function Inicializar()
    {
        $this->pessoa_logada = Auth::id();
        $retorno = 'Novo';

        // Captura segura de parâmetros
        $this->id = $_REQUEST['id'] ?? null;
        $this->ref_cod_instituicao = $_REQUEST['ref_cod_instituicao'] ?? null;
        $this->ref_cod_escola = $_REQUEST['ref_cod_escola'] ?? null;
        $this->ano = $_REQUEST['ano'] ?? date('Y');
        $this->mes = $_REQUEST['mes'] ?? null;

        $paramsCancelar = http_build_query([
            'ref_cod_instituicao' => $this->ref_cod_instituicao,
            'ref_cod_escola' => $this->ref_cod_escola,
            'ano' => $this->ano,
            'busca' => 'S'
        ]);
        $this->url_cancelar = "educar_frequencia_servidor_lst.php?{$paramsCancelar}";
        $this->nome_url_cancelar = 'Cancelar';

        if (is_numeric($this->id) && $this->id > 0) {
            $retorno = 'Editar';
            if (!$this->carregaDadosDoRegistro()) {
                $this->mensagem = "Registro de frequência não encontrado.";
                $this->simpleRedirect("educar_frequencia_servidor_lst.php");
                return false;
            }

            $this->fexcluir = false;
            $obj_permissoes = new clsPermissoes();
            if ($obj_permissoes->permissao_excluir($this->processoAp, $this->pessoa_logada, 7)) {
                $this->fexcluir = true;
            }
        } else {
             // Defaults if not set
             if (!$this->ano) $this->ano = date('Y');
        }

        // Recupera dados do POST em caso de recarregamento/erro
        if ($_POST) {
            $this->observacoes = $_POST['observacoes'] ?? null;
            $dias_uteis_input = $_POST['dias_uteis'] ?? [];
            $faltas_input = $_POST['faltas'] ?? [];

            foreach ($dias_uteis_input as $servidor_id => $dias) {
                $this->frequencia_servidores[$servidor_id] = (object) [
                    'dias_uteis' => $dias,
                    'faltas' => $faltas_input[$servidor_id] ?? 0,
                    'faltas_justificadas' => $_POST['faltas_justificadas'][$servidor_id] ?? 0,
                    'faltas_compensadas' => $_POST['faltas_compensadas'][$servidor_id] ?? 0,
                ];
            }
        }

        $this->breadcrumb($this->id ? 'Editar Registro' : 'Novo Registro', [
            url('intranet/educar_servidores_index.php') => 'Servidores',
            $this->url_cancelar => 'Listagem'
        ]);

        return $retorno;
    }

    public function Gerar()
    {
        $this->campoOculto('id', $this->id);

        try {
            // 1. Seleção de Instituição e Escola
            if ($this->id) {
                 // Modo Edição: Apenas exibir
                $this->campoOculto('ref_cod_instituicao', $this->ref_cod_instituicao);
                $this->campoOculto('ref_cod_escola', $this->ref_cod_escola);

                $instituicao = DB::table('pmieducar.instituicao')
                    ->where('cod_instituicao', $this->ref_cod_instituicao)
                    ->value('nm_instituicao');

                $escola = DB::table('pmieducar.escola as e')
                    ->join('cadastro.pessoa as p', 'e.ref_idpes', '=', 'p.idpes')
                    ->where('e.cod_escola', $this->ref_cod_escola)
                    ->value('p.nome');

                $this->campoRotulo('nm_instituicao', 'Instituição', htmlspecialchars($instituicao ?? 'Não informada'));
                $this->campoRotulo('nm_escola', 'Escola', htmlspecialchars($escola ?? 'Não encontrada'));
            } else {
                // Modo Novo: Permitir seleção
                $this->inputsHelper()->dynamic('instituicao', ['value' => $this->ref_cod_instituicao]);
                $this->inputsHelper()->dynamic('escola', ['value' => $this->ref_cod_escola]);
            }

            // 2. Ano
            $this->campoNumero('ano', 'Ano', $this->ano, 4, 4, true);

            // 3. Seletor de Mês
            if ($this->ref_cod_escola && $this->ano) {
                 $opcoesMes = ['' => 'Selecione'] + $this->getMesesDisponiveis();
                 $mesDesabilitado = (bool)$this->id;

                 $this->campoLista(
                     'mes',
                     'Mês de Referência',
                     $opcoesMes,
                     $this->mes,
                     'onSelectMes(this.value)',
                     false, '', '', $mesDesabilitado
                 );
            } else {
                 $this->campoRotulo('aviso_filtros', 'Aviso', '<div class="alert alert-info">Selecione Escola e Ano para habilitar o mês.</div>');
            }

            // 4. Grid de Lançamento
            if ($this->mes && $this->ano && $this->ref_cod_escola) {
                // Carrega os dados (Método interno para garantir carregamento)
                $this->servidores = $this->buscarDadosFrequencia(
                    (int)$this->ref_cod_escola,
                    (int)$this->ano,
                    (int)$this->mes
                );

                if (!empty($this->servidores)) {
                    $this->addHtml('<tr><td colspan="2"><hr></td></tr>');
                    $this->addHtml('<tr><td colspan="2" class="formmdtd" style="padding: 0;">');
                    $this->addHtml($this->geraTabelaServidores());
                    $this->addHtml('</td></tr>');

                    // 5. Observações (Só mostra se tiver grid)
                    $this->addHtml('<tr><td colspan="2"><br></td></tr>');
                    $this->campoMemo('observacoes', 'Observações', $this->observacoes, 60, 5, false);
                } else {
                    $this->campoRotulo('aviso', 'Atenção', '<div class="alert alert-warning">Nenhum servidor ativo encontrado para esta escola.</div>');
                }
            } else if ($this->ref_cod_escola && $this->ano) {
                $this->campoRotulo('info', '', '<div class="alert alert-info">Selecione o mês para carregar a lista de servidores.</div>');
            }

        } catch (\Exception $e) {
            Log::error("Erro no formulário de frequência: " . $e->getMessage());
            $this->campoRotulo('erro_fatal', 'Erro', '<div class="alert alert-danger">Erro ao carregar dados.</div>');
        }
    }

    public function Novo()
    {
        $this->mes = $_POST['mes'] ?? null;
        if (!$this->validaEntrada()) return false;

        DB::beginTransaction();
        try {
            $registro_id = DB::table('modules.registro_frequencia')->insertGetId([
                'ref_cod_instituicao' => $this->ref_cod_instituicao,
                'ref_cod_escola' => $this->ref_cod_escola,
                'ano' => $this->ano,
                'mes' => $this->mes,
                'created_by' => $this->pessoa_logada,
                'created_at' => now()
            ]);

            $this->salvarDetalhes($registro_id);
            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error("Erro ao salvar frequência: " . $e->getMessage());
            $this->mensagem = "Erro ao salvar o registro.";
            return false;
        }

        $this->simpleRedirect($this->url_cancelar);
        return true;
    }

    public function Editar()
    {
        if (empty($this->mes) && !empty($this->id)) {
            $this->mes = DB::table('modules.registro_frequencia')->where('id', $this->id)->value('mes');
        }

        if (!$this->validaEntrada(true)) return false;

        DB::beginTransaction();
        try {
            DB::table('modules.registro_frequencia')
                ->where('id', $this->id)
                ->update([
                    'updated_by' => $this->pessoa_logada,
                    'updated_at' => now()
                ]);

            $dias_uteis_input = $_POST['dias_uteis'] ?? [];
            $faltas_input = $_POST['faltas'] ?? [];
            $obs = $_POST['observacoes'] ?? null;

            foreach ($dias_uteis_input as $servidor_id => $dias) {
                $updateData = [
                    'dias_uteis' => $dias,
                    'faltas' => $faltas_input[$servidor_id] ?? 0,
                    'observacoes' => $obs
                ];

                if(isset($_POST['faltas_justificadas'][$servidor_id])) {
                     $updateData['faltas_justificadas'] = $_POST['faltas_justificadas'][$servidor_id];
                }
                if(isset($_POST['faltas_compensadas'][$servidor_id])) {
                     $updateData['faltas_compensadas'] = $_POST['faltas_compensadas'][$servidor_id];
                }

                DB::table('modules.registro_frequencia_servidor')
                    ->where('registro_frequencia_id', $this->id)
                    ->where('ref_cod_servidor', $servidor_id)
                    ->update($updateData);
            }

            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error("Erro ao editar frequência: " . $e->getMessage());
            $this->mensagem = "Erro ao editar o registro.";
            return false;
        }

        $this->simpleRedirect("educar_frequencia_servidor_det.php?id={$this->id}");
        return true;
    }

    public function Excluir()
    {
        if (empty($this->id)) return false;

        DB::beginTransaction();
        try {
            DB::table('modules.registro_frequencia_servidor')->where('registro_frequencia_id', $this->id)->delete();
            DB::table('modules.registro_frequencia')->where('id', $this->id)->delete();
            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error("Erro ao excluir: " . $e->getMessage());
            $this->mensagem = "Erro ao excluir o registro.";
            return false;
        }

        $this->simpleRedirect($this->url_cancelar);
        return true;
    }

    // --- MÉTODOS DE SERVIÇO (LÓGICA DE NEGÓCIO) ---

    private function buscarDadosFrequencia(int $codEscola, int $ano, int $mes)
    {
        $dataInicioCompetencia = "{$ano}-{$mes}-01";

        // 1. Total de Faltas (Bruto)
        $sqlTotalFaltas = "
            (SELECT COUNT(DISTINCT fa.cod_falta_atraso)
             FROM pmieducar.falta_atraso fa
             WHERE fa.ref_cod_servidor = s.cod_servidor
               AND fa.ref_cod_escola = ?
               AND fa.tipo = 2
               AND fa.ativo = 1
               AND EXTRACT(MONTH FROM fa.data_falta_atraso) = ?
               AND EXTRACT(YEAR FROM fa.data_falta_atraso) = ?
            )";

        // 2. Faltas Justificadas
        $sqlFaltasJustificadas = "
            (SELECT COUNT(DISTINCT fa.cod_falta_atraso)
             FROM pmieducar.falta_atraso fa
             WHERE fa.ref_cod_servidor = s.cod_servidor
               AND fa.ref_cod_escola = ?
               AND fa.tipo = 2
               AND fa.justificada = 0
               AND fa.ativo = 1
               AND EXTRACT(MONTH FROM fa.data_falta_atraso) = ?
               AND EXTRACT(YEAR FROM fa.data_falta_atraso) = ?
            )";

        // 3. Faltas Compensadas (Janela Estendida)
        $sqlFaltasCompensadas = "
            (SELECT COUNT(DISTINCT fac.cod_compensado)
             FROM pmieducar.falta_atraso_compensado fac
             WHERE fac.ref_cod_servidor = s.cod_servidor
               AND fac.ref_cod_escola = ?
               AND fac.ativo = 1
               AND fac.data_inicio >= CAST(? AS DATE)
               AND fac.data_inicio < (CAST(? AS DATE) + INTERVAL '2 MONTH')
            )";

        $sql = "
            SELECT
                s.cod_servidor,
                p.nome,
                COALESCE(funcao.nm_funcao, 'Não informado') AS funcao,
                COALESCE(fv.nm_vinculo, 'Não informado') AS nm_regime,
                fa.carga_horaria,
                $sqlTotalFaltas AS qtd_total_faltas_sistema,
                $sqlFaltasJustificadas AS qtd_justificadas_sistema,
                $sqlFaltasCompensadas AS qtd_compensadas_sistema
            FROM pmieducar.servidor s
            JOIN cadastro.pessoa p ON (p.idpes = s.cod_servidor)
            JOIN pmieducar.servidor_alocacao sa ON (sa.ref_cod_servidor = s.cod_servidor)
            LEFT JOIN portal.funcionario_vinculo fv ON (sa.ref_cod_funcionario_vinculo = fv.cod_funcionario_vinculo)
            LEFT JOIN pmieducar.servidor_funcao sf ON (sa.ref_cod_servidor_funcao = sf.cod_servidor_funcao)
            LEFT JOIN pmieducar.funcao ON (funcao.cod_funcao = sf.ref_cod_funcao)
            LEFT JOIN (
                SELECT ref_cod_servidor, SUM(sa.carga_horaria) AS carga_horaria
                FROM pmieducar.servidor_alocacao sa
                WHERE sa.ref_cod_escola = ?
                GROUP BY sa.ref_cod_servidor
            ) fa ON fa.ref_cod_servidor = s.cod_servidor
            WHERE s.ativo = 1 AND sa.ref_cod_escola = ?
            GROUP BY s.cod_servidor, p.nome, funcao.nm_funcao, fv.nm_vinculo, fa.carga_horaria
            ORDER BY p.nome ASC;
        ";

        $params = [
            $codEscola, $mes, $ano,
            $codEscola, $mes, $ano,
            $codEscola, $dataInicioCompetencia, $dataInicioCompetencia,
            $codEscola,
            $codEscola
        ];

        return DB::select($sql, $params);
    }

    private function salvarDetalhes($registro_id)
    {
        $dias_uteis_input = $_POST['dias_uteis'] ?? [];
        $faltas_input = $_POST['faltas'] ?? [];
        $just_input = $_POST['faltas_justificadas'] ?? [];
        $comp_input = $_POST['faltas_compensadas'] ?? [];
        $obs = $_POST['observacoes'] ?? null;

        $insertData = [];
        foreach ($dias_uteis_input as $servidor_id => $dias) {
            $insertData[] = [
                'registro_frequencia_id' => $registro_id,
                'ref_cod_servidor' => $servidor_id,
                'ref_cod_instituicao' => $this->ref_cod_instituicao,
                'dias_uteis' => $dias,
                'faltas' => $faltas_input[$servidor_id] ?? 0,
                'faltas_justificadas' => $just_input[$servidor_id] ?? 0,
                'faltas_compensadas' => $comp_input[$servidor_id] ?? 0,
                'observacoes' => $obs,
            ];
        }

        if (!empty($insertData)) {
            DB::table('modules.registro_frequencia_servidor')->insert($insertData);
        }
    }

    private function validaEntrada($is_edit = false)
    {
        if (empty($this->ref_cod_instituicao)) {
             $this->mensagem = "Selecione a Instituição.";
             return false;
        }
        if (empty($this->ref_cod_escola)) {
             $this->mensagem = "Selecione a Escola.";
             return false;
        }

        $mes_a_validar = $is_edit ? $this->mes : ($_POST['mes'] ?? null);
        if (empty($mes_a_validar)) {
            $this->mensagem = "Selecione o Mês de Referência.";
            return false;
        }

        if (!$is_edit) {
            $existe = DB::table('modules.registro_frequencia')
                ->where('ref_cod_escola', $this->ref_cod_escola)
                ->where('ano', $this->ano)
                ->where('mes', $mes_a_validar)
                ->exists();

            if ($existe) {
                $this->mensagem = "Já existe registro para este período.";
                return false;
            }
        }
        return true;
    }

    private function carregaDadosDoRegistro()
    {
        $registro = DB::table('modules.registro_frequencia')->where('id', $this->id)->first();
        if (!$registro) return false;

        $this->ref_cod_instituicao = $registro->ref_cod_instituicao;
        $this->ref_cod_escola = $registro->ref_cod_escola;
        $this->ano = $registro->ano;
        $this->mes = $registro->mes;

        $frequencias = DB::table('modules.registro_frequencia_servidor')
            ->where('registro_frequencia_id', $this->id)
            ->get();

        $this->frequencia_servidores = [];
        foreach ($frequencias as $freq) {
            $this->frequencia_servidores[$freq->ref_cod_servidor] = $freq;
        }

        if ($frequencias->isNotEmpty()) {
            $this->observacoes = $frequencias[0]->observacoes;
        }
        return true;
    }

    private function geraTabelaServidores()
    {
        $html = '<table class="tablelistagem" style="width:100%;">';
        $html .= '<thead><tr>';
        $html .= '<td class="formdktd" style="width: 40px;">Nº</td>';
        $html .= '<td class="formdktd">Nome do Servidor</td>';
        $html .= '<td class="formdktd" style="text-align:center; width: 80px;">C.H.</td>';
        $html .= '<td class="formdktd" style="text-align:center; width: 100px;">Dias Úteis</td>';
        $html .= '<td class="formdktd" style="text-align:center; width: 100px;">Faltas</td>';
        $html .= '<td class="formdktd" style="text-align:center; width: 100px; background-color: #e6f3ff;">Compensadas</td>';
        $html .= '<td class="formdktd" style="text-align:center; width: 100px; background-color: #e6ffe6;">Justificadas</td>';
        $html .= '</tr></thead><tbody>';

        $counter = 1;
        foreach ($this->servidores as $key => $servidor) {
            $row_class = ($key % 2 == 0) ? 'formlttd' : 'formmdtd';

            if ($this->id && isset($this->frequencia_servidores[$servidor->cod_servidor])) {
                // Modo Edição
                $saved = $this->frequencia_servidores[$servidor->cod_servidor];
                $dias_val = $saved->dias_uteis;
                $faltas_val = $saved->faltas;
                $comp_val = $saved->faltas_compensadas;
                $just_val = $saved->faltas_justificadas;
            } else {
                // Modo Novo
                $dias_val = '';
                $faltas_val = $servidor->qtd_total_faltas_sistema;
                $just_val = $servidor->qtd_justificadas_sistema;
                $divida = max(0, $faltas_val - $just_val);
                $comp_val = min($servidor->qtd_compensadas_sistema, $divida);
            }

            $nome = htmlspecialchars($servidor->nome);
            $funcao = htmlspecialchars($servidor->funcao);
            $ch = $servidor->carga_horaria ? gmdate("H:i", $servidor->carga_horaria * 3600) . 'h' : '-';

            $icon = ($key == 0) ? "<a href='javascript:void(0);' class='replica-icon' onclick=\"replicarValor('%s')\" title='Replicar para todos' style='margin-left: 5px; color:#555;'><i class='fa fa-clone'></i></a>" : "";
            $icon_dias = sprintf($icon, 'dias_uteis');
            $icon_faltas = sprintf($icon, 'faltas');

            $inputStyle = "style='width: 60px; display: inline-block; text-align: center;'";

            $html .= "<tr>
                <td class='{$row_class}'>{$counter}</td>
                <td class='{$row_class}'>
                    <b>{$nome}</b><br>
                    <span style='font-size:10px; color:#666'>{$funcao}</span>
                </td>
                <td class='{$row_class}' style='text-align:center'>{$ch}</td>

                <td class='{$row_class}' style='text-align:center;'>
                    <div style='display:flex; justify-content:center; align-items:center;'>
                        <input type='number' name='dias_uteis[{$servidor->cod_servidor}]' class='form-control dias_uteis' value='{$dias_val}' min='1' max='31' required {$inputStyle}>
                        {$icon_dias}
                    </div>
                </td>

                <td class='{$row_class}' style='text-align:center;'>
                    <div style='display:flex; justify-content:center; align-items:center;'>
                        <input type='number' name='faltas[{$servidor->cod_servidor}]' class='form-control faltas' value='{$faltas_val}' min='0' required {$inputStyle}>
                        {$icon_faltas}
                    </div>
                </td>

                <td class='{$row_class}' style='text-align:center; background-color: #f0f8ff;'>
                    <input type='number' name='faltas_compensadas[{$servidor->cod_servidor}]' class='form-control' value='{$comp_val}' readonly {$inputStyle} style='width: 60px; background-color: #e6f3ff; border: 1px solid #b3d9ff; color: #31708f;'>
                </td>

                <td class='{$row_class}' style='text-align:center; background-color: #f0fff0;'>
                    <input type='number' name='faltas_justificadas[{$servidor->cod_servidor}]' class='form-control' value='{$just_val}' readonly {$inputStyle} style='width: 60px; background-color: #e6ffe6; border: 1px solid #b3ffb3; color: #3c763d;'>
                </td>
            </tr>";
            $counter++;
        }
        $html .= '</tbody></table>';
        return $html;
    }

    private function getMesesDisponiveis()
    {
        $sql = "SELECT mes FROM modules.registro_frequencia WHERE ano = ? AND ref_cod_escola = ?";
        $params = [$this->ano, $this->ref_cod_escola];

        if ($this->id) {
            $sql .= " AND mes != ?";
            $params[] = $this->mes;
        }

        $registrados = DB::select($sql, $params);
        $usados = array_map(fn($i) => $i->mes, $registrados);
        $todos = [1=>'Janeiro', 2=>'Fevereiro', 3=>'Março', 4=>'Abril', 5=>'Maio', 6=>'Junho', 7=>'Julho', 8=>'Agosto', 9=>'Setembro', 10=>'Outubro', 11=>'Novembro', 12=>'Dezembro'];

        return array_diff_key($todos, array_flip($usados));
    }

    public function makeExtra()
    {
        return file_get_contents(__DIR__ . '/scripts/extra/educar-frequencia-servidor-cad.js');
    }
};
