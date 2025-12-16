<?php

namespace App\Http\Controllers;

use App\Models\LegacyRegistration;
use App_Model_MatriculaSituacao;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

class DashboardController extends Controller
{
    public function index(Request $request): View
    {
        $year = $request->input('year', date('Y'));

        if (!is_numeric($year)) {
             $year = date('Y');
        }

        // Statistics
        $studentsCount = LegacyRegistration::where('ano', $year)
            ->where('ativo', 1)
            ->distinct('ref_cod_aluno')
            ->count();

        $enrollmentsCount = LegacyRegistration::where('ano', $year)
            ->where('ativo', 1)
            ->count();

        $transferredCount = LegacyRegistration::where('ano', $year)
            ->where('ativo', 1)
            ->where('aprovado', App_Model_MatriculaSituacao::TRANSFERIDO)
            ->count();

        $reclassifiedCount = LegacyRegistration::where('ano', $year)
            ->where('ativo', 1)
            ->where('aprovado', App_Model_MatriculaSituacao::RECLASSIFICADO)
            ->count();

        $dropoutsCount = LegacyRegistration::where('ano', $year)
            ->where('ativo', 1)
            ->where('aprovado', App_Model_MatriculaSituacao::ABANDONO)
            ->count();

        // Enrollment Evolution Chart (Last 3 years)
        $years = [$year - 2, $year - 1, $year];
        $evolutionData = [];

        // Pre-fetch data for optimization could be done, but loop is simple enough for 3 iterations
        foreach ($years as $y) {
            $total = LegacyRegistration::where('ano', $y)->where('ativo', 1)->count();

            $boys = LegacyRegistration::where('ano', $y)
                ->where('ativo', 1)
                ->whereHas('student.person', function($q) {
                    $q->where('sexo', 'M');
                })
                ->count();

            $girls = LegacyRegistration::where('ano', $y)
                ->where('ativo', 1)
                ->whereHas('student.person', function($q) {
                    $q->where('sexo', 'F');
                })
                ->count();

            $evolutionData[] = [
                'year' => $y,
                'total' => $total,
                'boys' => $boys,
                'girls' => $girls
            ];
        }

        // Attendance Chart
        // Calculate average attendance for active students in the selected year
        // We filter by 'ativo' = 1 to get valid registrations
        // We might want to filter only for students who are "Cursando" (EM_ANDAMENTO) or similar,
        // but the request implies global stats.
        $avgAttendance = 0;
        try {
            $avgAttendance = DB::table('pmieducar.matricula')
                ->where('ano', $year)
                ->where('ativo', 1)
                ->selectRaw('AVG(modules.frequencia_da_matricula(cod_matricula)) as avg')
                ->value('avg');
        } catch (\Exception $e) {
            // Function might fail or not exist in some envs, handle gracefully
            // For now, we assume it works as it is part of the migration
            $avgAttendance = 0;
        }

        $avgAttendance = $avgAttendance ? round($avgAttendance, 1) : 0;
        $absentPercentage = round(100 - $avgAttendance, 1);

        // If attendance is 0 (no data), avoid showing 100% absent if it's just lack of data?
        // But 0 attendance is possible.
        // If query returns null (no students), avg is null -> 0 -> 100% absent.
        // Maybe check if there are students.
        if ($enrollmentsCount == 0) {
            $avgAttendance = 0;
            $absentPercentage = 0;
        }

        $updatedAt = date('H:i d/m/Y');

        return view('dashboard', compact(
            'year',
            'studentsCount',
            'enrollmentsCount',
            'transferredCount',
            'reclassifiedCount',
            'dropoutsCount',
            'evolutionData',
            'avgAttendance',
            'absentPercentage',
            'updatedAt'
        ));
    }
}
