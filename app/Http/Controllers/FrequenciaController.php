<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class FrequenciaController extends Controller
{
    public function lancamento()
    {
        return view('frequencia.lancamento');
    }

    public function espelho()
    {
        return view('frequencia.espelho');
    }
}
