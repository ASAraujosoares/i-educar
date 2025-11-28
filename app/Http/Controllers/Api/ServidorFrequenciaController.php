<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ServidorFrequencia;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ServidorFrequenciaController extends Controller
{
    public function __construct()
    {
        $this->middleware('can:menu-process,9998920');
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'frequencias' => 'required|array',
            'frequencias.*.servidor_id' => 'required|integer',
            'frequencias.*.data' => 'required|date',
            'frequencias.*.status' => 'required|string|in:Presente,Falta,Falta Justificada,Atestado,Folga',
            'frequencias.*.observacao' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $frequencias = [];
        foreach ($request->frequencias as $frequenciaData) {
            $frequencia = ServidorFrequencia::create([
                'servidor_id' => $frequenciaData['servidor_id'],
                'data' => $frequenciaData['data'],
                'status' => $frequenciaData['status'],
                'observacao' => $frequenciaData['observacao'] ?? null,
                'registrado_por_usuario_id' => auth()->id(),
            ]);
            $frequencias[] = $frequencia;
        }

        return response()->json($frequencias, 201);
    }

    public function update(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|string|in:Presente,Falta,Falta Justificada,Atestado,Folga',
            'observacao' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $frequencia = ServidorFrequencia::findOrFail($id);
        $frequencia->update($request->all());

        return response()->json($frequencia);
    }

    public function show($servidor_id, Request $request)
    {
        $validator = Validator::make($request->all(), [
            'mes' => 'required|integer|between:1,12',
            'ano' => 'required|integer',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $frequencias = ServidorFrequencia::where('servidor_id', $servidor_id)
            ->whereMonth('data', $request->mes)
            ->whereYear('data', $request->ano)
            ->get();

        return response()->json($frequencias);
    }

    public function diario(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'data' => 'required|date',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $frequencias = ServidorFrequencia::where('data', $request->data)->get();

        return response()->json($frequencias);
    }
}
