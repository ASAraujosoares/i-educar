<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;

return new class extends clsDetalhe
{
    public $titulo;
    public $id;

    public function Gerar()
    {
        $this->titulo = "Registro de Frequência de Servidores - Detalhe";
        $this->processoAp = 999888;

        $this->id = $_GET['id'] ?? null;

        if (!$this->id) {
            $this->simpleRedirect('educar_frequencia_servidor_lst.php');
        }

        $registro = DB::table('modules.registro_frequencia as rf')
            ->select('rf.*', 'p.nome as nm_escola', 'i.nm_instituicao')
            ->join('pmieducar.escola as e', 'e.cod_escola', '=', 'rf.ref_cod_escola')
            ->join('cadastro.pessoa as p', 'p.idpes', '=', 'e.ref_idpes')
            ->join('pmieducar.instituicao as i', 'i.cod_instituicao', '=', 'rf.ref_cod_instituicao')
            ->where('rf.id', $this->id)
            ->first();

        if (!$registro) {
            $this->simpleRedirect('educar_frequencia_servidor_lst.php');
        }

        $meses = [1=>'Janeiro', 2=>'Fevereiro', 3=>'Março', 4=>'Abril', 5=>'Maio', 6=>'Junho', 7=>'Julho', 8=>'Agosto', 9=>'Setembro', 10=>'Outubro', 11=>'Novembro', 12=>'Dezembro'];
        $nm_mes = $meses[$registro->mes] ?? $registro->mes;

        $this->addDetalhe(['Instituição', $registro->nm_instituicao]);
        $this->addDetalhe(['Escola', $registro->nm_escola]);
        $this->addDetalhe(['Ano', $registro->ano]);
        $this->addDetalhe(['Mês', $nm_mes]);

        // Details Table
        $detalhes = DB::table('modules.registro_frequencia_servidor as rfs')
            ->select('rfs.*', 'p.nome as nm_servidor')
            ->join('pmieducar.servidor as s', 's.cod_servidor', '=', 'rfs.ref_cod_servidor')
            ->join('cadastro.pessoa as p', 'p.idpes', '=', 's.cod_servidor')
            ->where('rfs.registro_frequencia_id', $this->id)
            ->orderBy('p.nome')
            ->get();

        $html = '<br><table class="tablelistagem" style="width: 100%;">';
        $html .= '<thead><tr>';
        $html .= '<td class="formdktd">Nome do Servidor</td>';
        $html .= '<td class="formdktd" style="text-align:center;">Dias Úteis</td>';
        $html .= '<td class="formdktd" style="text-align:center;">Faltas</td>';
        $html .= '<td class="formdktd" style="text-align:center;">Compensadas</td>';
        $html .= '<td class="formdktd" style="text-align:center;">Justificadas</td>';
        $html .= '<td class="formdktd">Observações</td>';
        $html .= '</tr></thead><tbody>';

        foreach ($detalhes as $idx => $row) {
             $class = ($idx % 2 == 0) ? 'formlttd' : 'formmdtd';
             $html .= "<tr>
                <td class='{$class}'>{$row->nm_servidor}</td>
                <td class='{$class}' style='text-align:center;'>{$row->dias_uteis}</td>
                <td class='{$class}' style='text-align:center;'>{$row->faltas}</td>
                <td class='{$class}' style='text-align:center;'>{$row->faltas_compensadas}</td>
                <td class='{$class}' style='text-align:center;'>{$row->faltas_justificadas}</td>
                <td class='{$class}'>" . nl2br(htmlspecialchars($row->observacoes ?? '')) . "</td>
             </tr>";
        }
        $html .= '</tbody></table>';

        $this->addHtml($html);

        // Buttons
        $obj_permissoes = new clsPermissoes();
        if ($obj_permissoes->permissao_cadastra(999888, Auth::id(), 7)) {
            $this->url_editar = "educar_frequencia_servidor_cad.php?id={$this->id}";
        }
        // Excluir button will be available in the Edit form if user has permission

        $this->url_cancelar = "educar_frequencia_servidor_lst.php";
        $this->largura = '100%';

        $this->breadcrumb('Detalhe do Registro', [
            url('intranet/educar_servidores_index.php') => 'Servidores',
            'educar_frequencia_servidor_lst.php' => 'Listagem'
        ]);
    }

    public function Formular()
    {
        $this->titulo = 'Servidores - Frequência';
        $this->processoAp = 999888;
    }
};
