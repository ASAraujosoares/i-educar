@extends('layout.default')

@section('content')
<div class="container-fluid" style="padding: 20px;">
    <!-- Top Cards -->
    <div class="row mb-4">
        <div class="col-md-2" style="width: 20%; float: left; padding: 0 10px;">
            <div class="card text-center" style="background: #fff; border: 1px solid #ddd; border-radius: 5px; padding: 20px;">
                <div style="font-size: 24px; color: #5b9bd5;">
                    <i class="fa fa-graduation-cap"></i>
                </div>
                <div style="color: #666; font-size: 14px;">Alunos</div>
                <div style="font-size: 20px; font-weight: bold;">{{ number_format($studentsCount, 0, ',', '.') }}</div>
            </div>
        </div>
        <div class="col-md-2" style="width: 20%; float: left; padding: 0 10px;">
            <div class="card text-center" style="background: #fff; border: 1px solid #ddd; border-radius: 5px; padding: 20px;">
                <div style="font-size: 24px; color: #5b9bd5;">
                    <i class="fa fa-clipboard"></i>
                </div>
                <div style="color: #666; font-size: 14px;">Matrículas</div>
                <div style="font-size: 20px; font-weight: bold;">{{ number_format($enrollmentsCount, 0, ',', '.') }}</div>
            </div>
        </div>
        <div class="col-md-2" style="width: 20%; float: left; padding: 0 10px;">
            <div class="card text-center" style="background: #fff; border: 1px solid #ddd; border-radius: 5px; padding: 20px;">
                <div style="font-size: 24px; color: #5b9bd5;">
                    <i class="fa fa-refresh"></i>
                </div>
                <div style="color: #666; font-size: 14px;">Transferidos</div>
                <div style="font-size: 20px; font-weight: bold;">{{ number_format($transferredCount, 0, ',', '.') }}</div>
            </div>
        </div>
        <div class="col-md-2" style="width: 20%; float: left; padding: 0 10px;">
            <div class="card text-center" style="background: #fff; border: 1px solid #ddd; border-radius: 5px; padding: 20px;">
                <div style="font-size: 24px; color: #5b9bd5;">
                    <i class="fa fa-level-up"></i>
                </div>
                <div style="color: #666; font-size: 14px;">Reclassificados</div>
                <div style="font-size: 20px; font-weight: bold;">{{ number_format($reclassifiedCount, 0, ',', '.') }}</div>
            </div>
        </div>
        <div class="col-md-2" style="width: 20%; float: left; padding: 0 10px;">
            <div class="card text-center" style="background: #fff; border: 1px solid #ddd; border-radius: 5px; padding: 20px;">
                <div style="font-size: 24px; color: #5b9bd5;">
                    <i class="fa fa-train"></i> <!-- Using train icon as closer match to image or similar -->
                </div>
                <div style="color: #666; font-size: 14px;">Abandonos</div>
                <div style="font-size: 20px; font-weight: bold;">{{ number_format($dropoutsCount, 0, ',', '.') }}</div>
            </div>
        </div>
        <div style="clear: both;"></div>
    </div>

    <br>

    <!-- Charts Row -->
    <div class="row">
        <!-- Enrollment Evolution Chart -->
        <div class="col-md-7" style="width: 58%; float: left; background: #fff; padding: 20px; margin-right: 2%; border: 1px solid #ddd; border-radius: 5px;">
            <h5 class="text-center" style="color: #666; text-align: center;">Evolução das matrículas</h5>
            <canvas id="evolutionChart" style="width: 100%; height: 300px;"></canvas>
        </div>

        <!-- Attendance Chart -->
        <div class="col-md-5" style="width: 40%; float: left; background: #fff; padding: 20px; border: 1px solid #ddd; border-radius: 5px;">
            <h5 class="text-center" style="color: #666; text-align: center;">Frequência escolar</h5>
            <canvas id="attendanceChart" style="width: 100%; height: 300px;"></canvas>
            <div style="text-align: right; margin-top: 10px; color: #999; font-size: 12px;">
                Atualizado às: {{ $updatedAt }}
            </div>
        </div>
        <div style="clear: both;"></div>
    </div>

    <br>

    <!-- Filter -->
    <div class="row">
        <div class="col-md-12">
            <form method="GET" action="{{ route('dashboard') }}">
                <div class="form-group" style="width: 200px;">
                    <label for="year">Ano:</label>
                    <input type="number" class="form-control" id="year" name="year" value="{{ $year }}" onchange="this.form.submit()">
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Chart.js -->
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<script>
    document.addEventListener('DOMContentLoaded', function() {
        // Evolution Chart
        var ctxEvo = document.getElementById('evolutionChart').getContext('2d');
        var evolutionData = @json($evolutionData);

        var labels = evolutionData.map(function(d) { return d.year; });
        var dataTotal = evolutionData.map(function(d) { return d.total; });
        var dataBoys = evolutionData.map(function(d) { return d.boys; });
        var dataGirls = evolutionData.map(function(d) { return d.girls; });

        new Chart(ctxEvo, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Total',
                        data: dataTotal,
                        backgroundColor: '#4e79a7'
                    },
                    {
                        label: 'Meninos',
                        data: dataBoys,
                        backgroundColor: '#76b7b2'
                    },
                    {
                        label: 'Meninas',
                        data: dataGirls,
                        backgroundColor: '#a6cee3' // Adjust color to match image loosely
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                },
                plugins: {
                    legend: {
                        position: 'right'
                    }
                }
            }
        });

        // Attendance Chart
        var ctxAtt = document.getElementById('attendanceChart').getContext('2d');
        var avgAttendance = {{ $avgAttendance }};
        var absentPercentage = {{ $absentPercentage }};

        new Chart(ctxAtt, {
            type: 'pie',
            data: {
                labels: ['Ausentes', 'Presentes'],
                datasets: [{
                    data: [absentPercentage, avgAttendance],
                    backgroundColor: [
                        '#4e79a7', // Blueish for Absent in image? Wait, image has dark blue for Ausentes?
                        // Image: 80.3% Presentes (Lighter/Greyish Blue?), 19.7% Ausentes (Dark Blue)
                        // Legend in image: Ausentes (Dark Blue), Presentes (Light Blue)
                        // Let's swap colors to match image perception
                         '#4e79a7', // Dark Blue
                         '#a6cee3'  // Light Blue
                    ]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'right'
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                return context.label + ': ' + context.raw + '%';
                            }
                        }
                    }
                }
            }
        });
    });
</script>
@endsection
