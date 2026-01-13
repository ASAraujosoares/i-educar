<?php

use Illuminate\Support\Facades\DB;
use App\Models\LegacyUserType;

return new class extends clsListagem
{
    public $pessoa_logada;
    public $titulo;
    public $limite;
    public $offset;

    // Filters
    public $ref_cod_instituicao;
    public $ref_cod_escola;
    public $ano;

    public function Gerar()
    {
        $this->titulo = 'Registro de Frequência de Servidores - Listagem';

        foreach ($_GET as $var => $val) {
            $this->$var = ($val === '') ? null : $val;
        }

        // Defaults
        if (!$this->ano) $this->ano = date('Y');

        $this->addCabecalhos([
            'Instituição',
            'Escola',
            'Ano',
            'Mês'
        ]);

        // Filters
        $this->inputsHelper()->dynamic('instituicao', ['value' => $this->ref_cod_instituicao]);
        $this->inputsHelper()->dynamic('escola', ['value' => $this->ref_cod_escola]);
        $this->campoNumero('ano', 'Ano', $this->ano, 4, 4);

        // Paginator
        $this->limite = 20;
        $this->offset = ($_GET['pagina_' . $this->nome]) ? $_GET['pagina_' . $this->nome] * $this->limite - $this->limite : 0;

        // Query
        $query = DB::table('modules.registro_frequencia as rf')
            ->select('rf.id', 'rf.ano', 'rf.mes', 'p.nome as nm_escola', 'i.nm_instituicao')
            ->join('pmieducar.escola as e', 'e.cod_escola', '=', 'rf.ref_cod_escola')
            ->join('cadastro.pessoa as p', 'p.idpes', '=', 'e.ref_idpes')
            ->join('pmieducar.instituicao as i', 'i.cod_instituicao', '=', 'rf.ref_cod_instituicao')
            ->orderByDesc('rf.ano')
            ->orderByDesc('rf.mes');

        if ($this->ref_cod_instituicao) {
            $query->where('rf.ref_cod_instituicao', $this->ref_cod_instituicao);
        }
        if ($this->ref_cod_escola) {
            $query->where('rf.ref_cod_escola', $this->ref_cod_escola);
        }
        if ($this->ano) {
            $query->where('rf.ano', $this->ano);
        }

        $total = $query->count();
        $registros = $query->limit($this->limite)->offset($this->offset)->get();

        foreach ($registros as $reg) {
            $meses = [1=>'Janeiro', 2=>'Fevereiro', 3=>'Março', 4=>'Abril', 5=>'Maio', 6=>'Junho', 7=>'Julho', 8=>'Agosto', 9=>'Setembro', 10=>'Outubro', 11=>'Novembro', 12=>'Dezembro'];
            $nm_mes = $meses[$reg->mes] ?? $reg->mes;

            $url = "educar_frequencia_servidor_det.php?id={$reg->id}";

            $this->addLinhas([
                "<a href='{$url}'>{$reg->nm_instituicao}</a>",
                "<a href='{$url}'>{$reg->nm_escola}</a>",
                "<a href='{$url}'>{$reg->ano}</a>",
                "<a href='{$url}'>{$nm_mes}</a>"
            ]);
        }

        $this->addPaginador2(
            'educar_frequencia_servidor_lst.php',
            $total,
            $_GET,
            $this->nome,
            $this->limite
        );

        $obj_permissoes = new clsPermissoes();
        if ($obj_permissoes->permissao_cadastra(999888, $this->pessoa_logada, 7)) {
            $this->array_botao[] = 'Novo';
            $this->array_botao_url[] = "educar_frequencia_servidor_cad.php";
        }

        $this->largura = '100%';

        $this->breadcrumb('Listagem de Frequências', [
            url('intranet/educar_servidores_index.php') => 'Servidores',
        ]);
    }

    public function Formular()
    {
        $this->titulo = 'Servidores - Frequência';
        $this->processoAp = 999888;
    }
};
