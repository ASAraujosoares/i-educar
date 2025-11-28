<template>
    <div class="container">
        <h1>Lançamento de Frequência de Servidores</h1>
        <div class="form-group">
            <label for="data">Data</label>
            <input type="date" id="data" v-model="dataSelecionada" class="form-control">
        </div>
        <table class="table">
            <thead>
                <tr>
                    <th>Servidor</th>
                    <th>Status</th>
                    <th>Observação</th>
                </tr>
            </thead>
            <tbody>
                <tr v-for="(servidor, index) in servidores" :key="servidor.cod_servidor">
                    <td>{{ servidor.pessoa.nome }}</td>
                    <td>
                        <select v-model="frequencias[index].status" class="form-control">
                            <option value="Presente">Presente</option>
                            <option value="Falta">Falta</option>
                            <option value="Falta Justificada">Falta Justificada</option>
                            <option value="Atestado">Atestado</option>
                            <option value="Folga">Folga</option>
                        </select>
                    </td>
                    <td>
                        <input type="text" v-model="frequencias[index].observacao" class="form-control">
                    </td>
                </tr>
            </tbody>
        </table>
        <button class="btn btn-primary" @click="salvarFrequencia">Salvar</button>
    </div>
</template>

<script>
export default {
    data() {
        return {
            servidores: [],
            dataSelecionada: new Date().toISOString().slice(0, 10),
            frequencias: []
        };
    },
    mounted() {
        this.fetchServidores();
    },
    methods: {
        fetchServidores() {
            axios.get('/api/servidores')
                .then(response => {
                    this.servidores = response.data;
                    this.frequencias = this.servidores.map(servidor => ({
                        servidor_id: servidor.cod_servidor,
                        status: 'Presente',
                        observacao: ''
                    }));
                })
                .catch(error => {
                    console.error("Erro ao buscar servidores:", error);
                });
        },
        salvarFrequencia() {
            const dataParaSalvar = {
                frequencias: this.frequencias.map(f => ({
                    ...f,
                    data: this.dataSelecionada
                }))
            };

            axios.post('/api/servidor-frequencia', dataParaSalvar)
                .then(response => {
                    alert('Frequência salva com sucesso!');
                })
                .catch(error => {
                    console.error("Erro ao salvar frequência:", error);
                    alert('Erro ao salvar frequência.');
                });
        }
    }
};
</script>
