<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Employee;

class ServidorController extends Controller
{
    public function index()
    {
        // Garante que o usuário tenha permissão para ver os servidores
        $this->authorize('viewAny', Employee::class);

        $servidores = Employee::with('pessoa')->where('ativo', 1)->get();

        return response()->json($servidores);
    }
}
