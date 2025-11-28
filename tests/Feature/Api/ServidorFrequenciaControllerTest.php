<?php

namespace Tests\Feature\Api;

use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use App\Models\User;
use Tests\TestCase;

class ServidorFrequenciaControllerTest extends TestCase
{
    use DatabaseTransactions;

    protected $authorizedUser;
    protected $unauthorizedUser;
    protected $servidorId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->createUsersAndServidor();
    }

    private function createUsersAndServidor()
    {
        // Define o ID do processo para a funcionalidade
        $processId = 9998920;

        // Cria o menu/permissão para a funcionalidade
        DB::table('public.menus')->insert([
            'id' => 235,
            'parent_id' => 4, // Menu "Servidores"
            'title' => 'Frequência de Servidores',
            'process' => $processId,
            'active' => true,
            'type' => 3,
            'parent_old' => 71
        ]);

        // Cria um tipo de usuário que PODE acessar a funcionalidade
        $authorizedUserTypeId = DB::table('pmieducar.tipo_usuario')->insertGetId([
            'nm_tipo' => 'RH Autorizado',
            'nivel' => 1,
            'ativo' => 1,
            'ref_funcionario_cad' => 1, // Usuário admin padrão
        ], 'cod_tipo_usuario');

        // Associa a permissão ao tipo de usuário
        DB::table('pmieducar.menu_tipo_usuario')->insert([
            'ref_cod_tipo_usuario' => $authorizedUserTypeId,
            'menu_id' => 235,
            'visualiza' => 1,
            'cadastra' => 1,
            'exclui' => 1,
        ]);

        // Cria um tipo de usuário que NÃO PODE acessar
        $unauthorizedUserTypeId = DB::table('pmieducar.tipo_usuario')->insertGetId([
            'nm_tipo' => 'Usuário Comum',
            'nivel' => 2,
            'ativo' => 1,
            'ref_funcionario_cad' => 1,
        ], 'cod_tipo_usuario');

        // Cria o usuário autorizado
        $pessoaAuthId = DB::table('cadastro.pessoa')->insertGetId(['nm_pessoa' => 'Authorized User'], 'idpes');
        $this->authorizedUser = User::create([
            'ref_cod_pessoa_fj' => $pessoaAuthId,
            'login' => 'authuser' . time(),
            'senha' => bcrypt('password'),
            'ativo' => 1,
            'ref_cod_tipo_usuario' => $authorizedUserTypeId,
        ]);

        // Cria o usuário não autorizado
        $pessoaUnauthId = DB::table('cadastro.pessoa')->insertGetId(['nm_pessoa' => 'Unauthorized User'], 'idpes');
        $this->unauthorizedUser = User::create([
            'ref_cod_pessoa_fj' => $pessoaUnauthId,
            'login' => 'unauthuser' . time(),
            'senha' => bcrypt('password'),
            'ativo' => 1,
            'ref_cod_tipo_usuario' => $unauthorizedUserTypeId,
        ]);

        // Cria o servidor
        $pessoaServidorId = DB::table('cadastro.pessoa')->insertGetId(['nm_pessoa' => 'Test Employee'], 'idpes');
        $this->servidorId = DB::table('pmieducar.servidor')->insertGetId([
            'ref_cod_pessoa_fj' => $pessoaServidorId,
            'ativo' => 1,
        ], 'cod_servidor');
    }

    public function test_unauthenticated_user_cannot_access_endpoints()
    {
        $this->postJson('/api/servidor-frequencia')->assertStatus(401);
        $this->putJson('/api/servidor-frequencia/1')->assertStatus(401);
        $this->getJson('/api/servidor-frequencia/servidor/1')->assertStatus(401);
        $this->getJson('/api/servidor-frequencia/diario')->assertStatus(401);
    }

    public function test_user_without_permission_is_forbidden()
    {
        $this->actingAs($this->unauthorizedUser, 'api')
             ->postJson('/api/servidor-frequencia', [])
             ->assertStatus(403);
    }

    public function test_user_with_permission_can_store_frequencia()
    {
        $data = [
            'frequencias' => [
                [
                    'servidor_id' => $this->servidorId,
                    'data' => '2025-01-01',
                    'status' => 'Presente',
                ],
            ],
        ];

        $this->actingAs($this->authorizedUser, 'api')
            ->postJson('/api/servidor-frequencia', $data)
            ->assertStatus(201);
    }

    // ... (demais testes adaptados para usar $this->authorizedUser)
}
