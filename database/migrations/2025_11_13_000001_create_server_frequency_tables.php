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

                // Composite Foreign Key for Servidor
                // Reference strictly to pmieducar.servidor using composite key
                $table->foreign(['ref_cod_servidor', 'ref_cod_instituicao'])
                      ->references(['cod_servidor', 'ref_cod_instituicao'])
                      ->on('pmieducar.servidor');
            });
        }

        // 2. Create Menu and Permissions
        // Find parent menu "Servidores" by its legacy process ID (71)
        $parentMenu = Menu::query()->where('old', 71)->first();

        // Fallback to searching by title if ID 71 is not found (unlikely)
        if (!$parentMenu) {
            $parentMenu = Menu::query()
                ->where('title', 'Servidores')
                ->whereNull('parent_id')
                ->first();
        }

        // Only create if not already exists (check by process ID)
        $existingMenu = Menu::query()->where('process', 999888)->exists();

        if ($parentMenu && !$existingMenu) {
            $menu = Menu::query()->create([
                'parent_id' => $parentMenu->id,
                'title' => 'Frequência de Servidores',
                'description' => 'Frequência de Servidores',
                'link' => 'educar_frequencia_servidor_lst.php',
                'type' => 1, // Menu type
                'process' => 999888,
                'order' => 0,
                'old' => 999888,
                'active' => 1,
            ]);

            // Add permission for Admin (Level 1)
            // Using DB::table for pivot to be safe
            DB::table('pmieducar.menu_tipo_usuario')->insert([
                'menu_id' => $menu->id,
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
        $menu = Menu::query()->where('process', 999888)->first();
        if ($menu) {
            DB::table('pmieducar.menu_tipo_usuario')->where('menu_id', $menu->id)->delete();
            $menu->delete();
        }
    }
};
