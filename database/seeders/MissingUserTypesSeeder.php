<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class MissingUserTypesSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        DB::table('pmieducar.tipo_usuario')->updateOrInsert(
            ['cod_tipo_usuario' => 2],
            [
                'nm_tipo' => 'Diretor de Escola',
                'nivel' => 2,
                'ref_funcionario_cad' => 1,
                'data_cadastro' => now(),
            ]
        );

        DB::table('pmieducar.tipo_usuario')->updateOrInsert(
            ['cod_tipo_usuario' => 3],
            [
                'nm_tipo' => 'Servidor',
                'nivel' => 3,
                'ref_funcionario_cad' => 1,
                'data_cadastro' => now(),
            ]
        );
    }
}
