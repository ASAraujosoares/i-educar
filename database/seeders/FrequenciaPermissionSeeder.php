<?php

namespace Database\Seeders;

use App\Menu;
use App\Models\LegacyMenuUserType;
use App\Process;
use Illuminate\Database\Seeder;

class FrequenciaPermissionSeeder extends Seeder
{
    public function run()
    {
        $menu = Menu::updateOrCreate(
            ['id' => Process::FREQUENCIA],
            [
                'parent_id' => Process::MENU_EMPLOYEES,
                'title' => 'Frequência',
                'order' => 0,
                'link' => '/frequencia/lancamento',
                'process' => Process::FREQUENCIA,
            ]
        );

        LegacyMenuUserType::updateOrCreate(
            ['menu_id' => $menu->id, 'ref_cod_tipo_usuario' => 1],
            ['visualiza' => 1, 'cadastra' => 1, 'exclui' => 1]
        );

        LegacyMenuUserType::updateOrCreate(
            ['menu_id' => $menu->id, 'ref_cod_tipo_usuario' => 2],
            ['visualiza' => 1, 'cadastra' => 1, 'exclui' => 0]
        );

        LegacyMenuUserType::updateOrCreate(
            ['menu_id' => $menu->id, 'ref_cod_tipo_usuario' => 3],
            ['visualiza' => 1, 'cadastra' => 0, 'exclui' => 0]
        );
    }
}
