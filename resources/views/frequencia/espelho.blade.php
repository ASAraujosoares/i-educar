@extends('layouts.app')

@section('content')
    <div class="container">
        <h1>Espelho de Ponto</h1>
        <div class="form-group">
            <label for="mes">Mês</label>
            <select id="mes" name="mes" class="form-control">
                @for ($i = 1; $i <= 12; $i++)
                    <option value="{{ $i }}">{{ date('F', mktime(0, 0, 0, $i, 10)) }}</option>
                @endfor
            </select>
        </div>
        <div class="form-group">
            <label for="ano">Ano</label>
            <input type="number" id="ano" name="ano" class="form-control" value="{{ date('Y') }}">
        </div>
        <div id="calendario">

        </div>
    </div>
@endsection
