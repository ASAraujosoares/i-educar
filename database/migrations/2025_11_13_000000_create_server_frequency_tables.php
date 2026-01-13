<?php

use App\Menu;
use App\Models\LegacyUserType;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        // 1. Create Tables
        if (!Schema::hasTable('modules.registro_frequencia')) {
            Schema::create('modules.registro_frequencia', function (Blueprint $table) {
                $table->id();
                $table->integer('ref_cod_instituicao');
                $table->integer('ref_cod_escola');
                $table->integer('ano');
                $table->integer('mes');
                $table->integer('created_by')->nullable();
                $table->timestamp('created_at')->useCurrent();
                $table->integer('updated_by')->nullable();
                $table->timestamp('updated_at')->nullable();

                $table->foreign('ref_cod_instituicao')->references('cod_instituicao')->on('pmieducar.instituicao');
                $table->foreign('ref_cod_escola')->references('cod_escola')->on('pmieducar.escola');
                // Unique constraint to avoid duplicates
                $table->unique(['ref_cod_escola', 'ano', 'mes'], 'unique_freq_escola_periodo');
            });
        }

        if (!Schema::hasTable('modules.registro_frequencia_servidor')) {
            Schema::create('modules.registro_frequencia_servidor', function (Blueprint $table) {
                $table->foreignId('registro_frequencia_id')->constrained('modules.registro_frequencia')->onDelete('cascade');
                $table->integer('ref_cod_servidor');
                $table->integer('ref_cod_instituicao');
                $table->integer('dias_uteis')->default(0);
                $table->integer('faltas')->default(0);
                $table->integer('faltas_justificadas')->default(0);
                $table->integer('faltas_compensadas')->default(0);
                $table->text('observacoes')->nullable();

                $table->primary(['registro_frequencia_id', 'ref_cod_servidor'], 'pk_reg_freq_servidor');
                $table->foreign('ref_cod_servidor')->references('cod_servidor')->on('pmieducar.servidor');
            });
        }

        // 2. Create Menu and Permissions
        $parentMenu = Menu::query()
            ->where('title', 'Servidores')
            ->whereNull('parent_id') // Assuming Servidores is a root menu or near root, wait, usually it is under something else or root.
            ->first();

        // If not found as root, try searching by link or recursively.
        if (!$parentMenu) {
            $parentMenu = Menu::query()->where('link', 'ilike', '%educar_servidores_index.php%')->first();
        }

        if ($parentMenu) {
            $menuId = Menu::query()->insertGetId([
                'parent_id' => $parentMenu->id,
                'title' => 'Frequência de Servidores',
                'description' => 'Frequência de Servidores',
                'link' => 'educar_frequencia_servidor_lst.php',
                'type' => 1, // Menu type
                'process' => 999888,
                'order' => 0,
                'old' => 999888, // Using same ID for old reference
                'active' => 1,
            ]);

            // Add permission for Admin (Level 1)
            DB::table('pmieducar.menu_tipo_usuario')->insert([
                'menu_id' => $menuId,
                'ref_cod_tipo_usuario' => LegacyUserType::LEVEL_ADMIN,
                'visualiza' => 1,
                'cadastra' => 1,
                'exclui' => 1,
            ]);
        }
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        // Drop Tables
        Schema::dropIfExists('modules.registro_frequencia_servidor');
        Schema::dropIfExists('modules.registro_frequencia');

        // Remove Menu
        $menuId = Menu::query()->where('process', 999888)->value('id');
        if ($menuId) {
            DB::table('pmieducar.menu_tipo_usuario')->where('menu_id', $menuId)->delete();
            Menu::query()->where('id', $menuId)->delete();
        }
    }
};
