<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ServidorFrequencia extends Model
{
    use HasFactory;

    protected $table = 'pmieducar.servidor_frequencia';

    protected $fillable = [
        'servidor_id',
        'data',
        'status',
        'observacao',
        'registrado_por_usuario_id',
    ];

    public function servidor(): BelongsTo
    {
        return $this->belongsTo(Employee::class, 'servidor_id', 'cod_servidor');
    }

    public function registradoPor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'registrado_por_usuario_id', 'cod_usuario');
    }
}
