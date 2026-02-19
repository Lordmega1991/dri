'use client'

import { useEffect, useState, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { supabase } from '@/lib/supabaseClient'
import Link from 'next/link'
import { ArrowLeft, User, Plus, Trash2, Edit2, BarChart2, CheckCircle2, AlertCircle, Clock, Copy } from 'lucide-react'
import clsx from 'clsx'
import jsPDF from 'jspdf'
import autoTable from 'jspdf-autotable'

// Slot Definitions
const SLOTS = {
    'Manhã': ['M1', 'M2', 'M3', 'M4', 'M5', 'M6'],
    'Tarde': ['T1', 'T2', 'T3', 'T4', 'T5', 'T6'],
    'Noite': ['N1', 'N2', 'N3', 'N4']
}

const DIAS = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
const TURNOS = ['Manhã', 'Tarde', 'Noite']

function SimulacaoContent() {
    const searchParams = useSearchParams()
    const router = useRouter()
    const semestreId = searchParams.get('id') || ''

    const [loading, setLoading] = useState(true)
    const [disciplinas, setDisciplinas] = useState<any[]>([])
    const [professores, setProfessores] = useState<any[]>([])
    const [alocacoes, setAlocacoes] = useState<any[]>([])

    // Filter State
    const isImpar = semestreId.endsWith('.1')
    const [filterType, setFilterType] = useState<'Todos' | 'Impares' | 'Pares'>(isImpar ? 'Impares' : 'Pares')

    // Simulation State
    const [simulacoes, setSimulacoes] = useState<any[]>([])
    const [activeSimulacaoId, setActiveSimulacaoId] = useState<string | null>(null)
    const [excludedDisciplines, setExcludedDisciplines] = useState<string[]>([]) // IDs of disabled disciplines

    // Tab State
    const [activePeriodo, setActivePeriodo] = useState<string>('')
    const [semestreLabel, setSemestreLabel] = useState<string>('')

    // Modal State
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [selectedDisciplina, setSelectedDisciplina] = useState<any>(null)
    const [allocItems, setAllocItems] = useState<any[]>([]) // Array of allocations
    const [globalSettings, setGlobalSettings] = useState({
        sala: '',
        turma: 'A', // Hidden default
        turno: 'Manhã',
        dias: [] as string[],
        slots: [] as string[]
    })

    // Helper to strip titles for sorting
    const cleanName = (name: string) => {
        return name.replace(/^((PROF|PROFA|DR|DRA|ME|MA|ESP|PHD)[.\s]+)+/i, '').trim()
    }

    const sortedProfessores = [...professores].sort((a, b) => cleanName(a.nome).localeCompare(cleanName(b.nome)))

    const [userAccessLevel, setUserAccessLevel] = useState<number | null>(null)

    // Fetch initial data
    useEffect(() => {
        const checkAccess = async () => {
            const { data: { session } } = await supabase.auth.getSession()
            if (!session) {
                router.push('/login')
                return
            }

            const { data: accessData } = await supabase
                .from('users_access')
                .select('access_level')
                .eq('id', session.user.id)
                .single()

            if (!accessData || accessData.access_level < 2) {
                router.push('/')
                return
            }

            setUserAccessLevel(accessData.access_level)

            // Fetch semester label
            const { data: semData } = await supabase
                .from('semestres')
                .select('ano, semestre')
                .eq('id', semestreId)
                .single()

            if (semData) {
                setSemestreLabel(`${semData.ano}.${semData.semestre}`)
            }

            fetchSimulations()
        }
        checkAccess()
    }, [semestreId])

    const fetchSimulations = async () => {
        setLoading(true)
        const { data, error } = await supabase
            .from('simulacoes')
            .select('*')
            .eq('semestre', semestreId)
            .order('created_at', { ascending: false })

        if (data && data.length > 0) {
            setSimulacoes(data)
            setActiveSimulacaoId(data[0].id)
            setExcludedDisciplines(data[0].disciplinas_ignoradas || [])
        } else {
            // Create default simulation if none exists
            await createSimulation('Simulação Padrão')
        }
        setLoading(false)
    }

    const createSimulation = async (nome: string) => {
        const { data, error } = await supabase
            .from('simulacoes')
            .insert({ semestre: semestreId, nome })
            .select()
            .single()

        if (data) {
            setSimulacoes(prev => [data, ...prev])
            setActiveSimulacaoId(data.id)
            setExcludedDisciplines([])
            fetchData(data.id)
        }
    }

    const cloneSimulation = async () => {
        if (!activeSimulacaoId) return

        const nome = prompt("Nome da simulação clonada:")
        if (!nome) return

        setLoading(true)
        try {
            // Get current simulation data
            const currentSim = simulacoes.find(s => s.id === activeSimulacaoId)
            if (!currentSim) return

            // Create new simulation with same disciplinas_ignoradas
            const { data: newSim, error: simError } = await supabase
                .from('simulacoes')
                .insert({
                    semestre: semestreId,
                    nome,
                    disciplinas_ignoradas: currentSim.disciplinas_ignoradas || []
                })
                .select()
                .single()

            if (simError || !newSim) {
                alert('Erro ao criar simulação: ' + simError?.message)
                return
            }

            // Get all allocations from current simulation
            const { data: currentAllocations, error: alocError } = await supabase
                .from('alocacoes_docentes')
                .select('*')
                .eq('simulacao_id', activeSimulacaoId)

            if (alocError) {
                alert('Erro ao buscar alocações: ' + alocError.message)
                return
            }

            // Clone allocations to new simulation
            if (currentAllocations && currentAllocations.length > 0) {
                const newAllocations = currentAllocations.map(aloc => {
                    const { id, created_at, ...rest } = aloc // Remove id and created_at
                    return {
                        ...rest,
                        simulacao_id: newSim.id
                    }
                })

                const { error: insertError } = await supabase
                    .from('alocacoes_docentes')
                    .insert(newAllocations)

                if (insertError) {
                    alert('Erro ao copiar alocações: ' + insertError.message)
                    return
                }
            }

            // Update state and switch to new simulation
            setSimulacoes(prev => [newSim, ...prev])
            setActiveSimulacaoId(newSim.id)
            setExcludedDisciplines(newSim.disciplinas_ignoradas || [])
            fetchData(newSim.id)
        } catch (err: any) {
            console.error(err)
            alert('Erro ao clonar simulação: ' + err.message)
        } finally {
            setLoading(false)
        }
    }


    // Load Data when Sim ID changes
    useEffect(() => {
        if (activeSimulacaoId) {
            const sim = simulacoes.find(s => s.id === activeSimulacaoId)
            if (sim) setExcludedDisciplines(sim.disciplinas_ignoradas || [])
            fetchData(activeSimulacaoId)
        }
    }, [activeSimulacaoId])

    const fetchData = async (simId = activeSimulacaoId) => {
        if (!simId) return
        setLoading(true)
        try {
            const [discRes, profRes, alocRes] = await Promise.all([
                supabase.from('disciplinas').select('*').order('periodo').order('nome'),
                supabase.from('docentes').select('*').eq('ativo', true).order('nome'),
                supabase.from('alocacoes_docentes')
                    .select('*, professor:docentes(nome, apelido)')
                    .eq('simulacao_id', simId)
            ])

            if (discRes.data) {
                setDisciplinas(discRes.data)
                // Set initial active period
                if (!activePeriodo) {
                    const p = Array.from(new Set(discRes.data.map(d => d.periodo || 'Optativas'))).sort(sortPeriodos)
                    if (p.length > 0) setActivePeriodo(p[0])
                }
            }
            if (profRes.data) setProfessores(profRes.data)
            if (alocRes.data) setAlocacoes(alocRes.data)

        } catch (error) {
            console.error(error)
        } finally {
            setLoading(false)
        }
    }

    const sortPeriodos = (a: string, b: string) => {
        const numA = parseInt(a)
        const numB = parseInt(b)
        if (!isNaN(numA) && !isNaN(numB)) return numA - numB
        return String(a).localeCompare(String(b))
    }

    const openAllocationModal = (disciplina: any) => {
        setSelectedDisciplina(disciplina)

        // Load EXISTING allocations
        const existingAllocations = alocacoes.filter(a => a.disciplina_id === disciplina.id)

        if (existingAllocations.length > 0) {
            const first = existingAllocations[0]
            setGlobalSettings({
                sala: first.sala || '',
                turma: first.turma || 'A',
                turno: first.turno || disciplina.turno || 'Manhã',
                dias: first.dias || [],
                slots: first.slots || []
            })

            setAllocItems(existingAllocations.map(a => ({
                id: a.id,
                professor: a.docente_id,
                ch: a.ch_alocada
            })))
        } else {
            // New Allocation
            const remaining = (disciplina.ch_aula || 60)
            setAllocItems([{
                id: Math.random(),
                professor: '',
                ch: remaining > 0 ? remaining : 0,
            }])
            setGlobalSettings({
                sala: '',
                turma: 'A',
                turno: disciplina.turno || 'Manhã',
                dias: [],
                slots: []
            })
        }
        setIsModalOpen(true)
    }

    const addAllocItem = () => {
        setAllocItems([...allocItems, { id: Math.random(), professor: '', ch: 0 }])
    }

    const removeAllocItem = (index: number) => {
        const newItems = [...allocItems]
        newItems.splice(index, 1)
        setAllocItems(newItems)
    }

    const updateAllocItem = (index: number, field: string, value: any) => {
        const newItems = [...allocItems]
        newItems[index][field] = value
        setAllocItems(newItems)
    }

    const toggleDiscipline = async (discId: string) => {
        const isIgnored = excludedDisciplines.includes(discId)
        let newExcluded = isIgnored
            ? excludedDisciplines.filter(id => id !== discId)
            : [...excludedDisciplines, discId]

        setExcludedDisciplines(newExcluded)

        // Update Simulacoes State immediately to avoid stale data on switch
        setSimulacoes(prev => prev.map(s => s.id === activeSimulacaoId ? { ...s, disciplinas_ignoradas: newExcluded } : s))

        if (activeSimulacaoId) {
            await supabase
                .from('simulacoes')
                .update({ disciplinas_ignoradas: newExcluded })
                .eq('id', activeSimulacaoId)
        }
    }

    const handleSaveAllocation = async () => {
        if (allocItems.some(i => !i.professor)) return alert("Selecione todos os professores")

        try {
            await supabase
                .from('alocacoes_docentes')
                .delete()
                .eq('simulacao_id', activeSimulacaoId)
                .eq('disciplina_id', selectedDisciplina.id)

            const inserts = allocItems.map(item => ({
                simulacao_id: activeSimulacaoId,
                semestre: semestreId,
                disciplina_id: selectedDisciplina.id,
                docente_id: item.professor,
                ch_alocada: item.ch,
                turma: globalSettings.turma || 'A',
                sala: globalSettings.sala,
                dias: globalSettings.dias,
                turno: globalSettings.turno,
                slots: globalSettings.slots
            }))

            const { error } = await supabase.from('alocacoes_docentes').insert(inserts)
            if (error) throw error
            fetchData()
            setIsModalOpen(false)
        } catch (err: any) {
            console.error(err)
            if (err.message?.includes("column")) {
                alert("Erro de Schema: Verifique se rodou 'MIGRACAO_SIMULACOES.sql'.")
            } else {
                alert('Erro ao salvar: ' + err.message)
            }
        }
    }

    const toggleSlot = (dia: string, slot: string) => {
        const key = `${dia}-${slot}`
        setGlobalSettings(prev => {
            const exists = prev.slots.includes(key)
            let newSlots = exists ? prev.slots.filter(s => s !== key) : [...prev.slots, key]
            const activeDays = Array.from(new Set(newSlots.map(s => s.split('-')[0])))
            return { ...prev, slots: newSlots, dias: activeDays }
        })
    }

    const handleDelete = async (id: number) => {
        if (!confirm("Remover professor?")) return
        try {
            await supabase.from('alocacoes_docentes').delete().eq('id', id)
            fetchData()
        } catch (err) { console.error(err) }
    }

    // Derived State
    const periodos = Array.from(new Set(disciplinas.map(d => d.periodo || 'Optativas'))).sort(sortPeriodos)
    const visiblePeriodos = periodos.filter(p => {
        const num = parseInt(p)
        if (isNaN(num)) return true
        if (filterType === 'Impares') return num % 2 !== 0
        if (filterType === 'Pares') return num % 2 === 0
        return true
    })

    useEffect(() => {
        if (visiblePeriodos.length > 0 && !visiblePeriodos.includes(activePeriodo)) {
            setActivePeriodo(visiblePeriodos[0])
        }
    }, [filterType, visiblePeriodos])

    const activeDisciplines = disciplinas
        .filter(d => (d.periodo || 'Optativas') === activePeriodo)
        .map(disc => {
            const discAlocs = alocacoes.filter(a => a.disciplina_id === disc.id)
            const allocated = discAlocs.reduce((sum, a) => sum + (a.ch_alocada || 0), 0)
            return {
                ...disc,
                allocated,
                isComplete: allocated >= (disc.ch_aula || 0),
                isIgnored: excludedDisciplines.includes(disc.id)
            }
        })
        .sort((a, b) => {
            // First: Ignored disciplines go last
            if (a.isIgnored !== b.isIgnored) return a.isIgnored ? 1 : -1

            // Second: Completed disciplines go to the end (before ignored)
            if (a.isComplete !== b.isComplete) return a.isComplete ? 1 : -1

            // Third: Alphabetically by name
            return a.nome.localeCompare(b.nome)
        })

    const totalCH = activeDisciplines
        .filter(d => !excludedDisciplines.includes(d.id))
        .reduce((sum, d) => sum + (d.ch_aula || 0), 0)

    const allocatedCH = activeDisciplines
        .filter(d => !excludedDisciplines.includes(d.id))
        .reduce((sum, d) => sum + (d.allocated || 0), 0)

    const progress = totalCH > 0 ? (allocatedCH / totalCH) * 100 : 0

    // New Features
    const handleDeleteSimulation = async () => {
        if (!activeSimulacaoId) return
        if (!confirm('Tem certeza que deseja excluir esta simulação? Todas as alocações serão perdidas permanentemente.')) return

        setLoading(true)
        const { error } = await supabase
            .from('simulacoes')
            .delete()
            .eq('id', activeSimulacaoId)

        if (error) {
            alert('Erro ao excluir: ' + error.message)
            setLoading(false)
        } else {
            fetchSimulations()
        }
    }

    const generatePDF = () => {
        const doc = new jsPDF()

        // Helper: Detect shift from slots
        const detectShiftFromSlots = (slots: string[]) => {
            if (!slots || slots.length === 0) return 'Manhã'

            // Extract slot codes (M1, T2, N3, etc.)
            const slotCodes = slots.map(s => {
                const parts = s.split('-')
                return parts[1] || ''
            })

            const hasManha = slotCodes.some(s => s.startsWith('M'))
            const hasTarde = slotCodes.some(s => s.startsWith('T'))
            const hasNoite = slotCodes.some(s => s.startsWith('N'))

            // If multiple shifts, return the first one found
            if (hasNoite) return 'Noite'
            if (hasTarde) return 'Tarde'
            if (hasManha) return 'Manhã'

            return 'Manhã' // Default
        }

        // Helper: Format day-shift (e.g., "Seg-Manhã")
        const formatDayShift = (dias: string[], slots: string[], turno: string) => {
            if (!dias || dias.length === 0) return '-'

            // Detect actual shift from slots if available
            const actualShift = slots && slots.length > 0 ? detectShiftFromSlots(slots) : turno

            return dias.map(d => `${d}-${actualShift}`).join(', ')
        }

        // Helper: Add institutional header to page
        const addHeader = (pageTitle: string) => {
            doc.setFontSize(11)
            doc.setFont('helvetica', 'bold')
            doc.text('UFPB - CCSA - DEPARTAMENTO DE RELAÇÕES INTERNACIONAIS', 105, 15, { align: 'center' })

            doc.setFontSize(10)
            doc.text('Simulação das Cargas Horárias Docentes', 105, 22, { align: 'center' })

            doc.setFontSize(10)
            doc.setFont('helvetica', 'normal')
            const currentSimName = simulacoes.find(s => s.id === activeSimulacaoId)?.nome || 'Simulação'
            doc.text(`Semestre: ${semestreLabel || semestreId} | Cenário: ${currentSimName}`, 105, 29, { align: 'center' })

            if (pageTitle) {
                doc.setFontSize(11)
                doc.setFont('helvetica', 'bold')
                doc.text(pageTitle.replace('ºº', 'º'), 14, 38)
            }
        }

        // Helper: Add footer
        const addFooter = () => {
            const pageNum = (doc as any).internal.getNumberOfPages()
            doc.setFontSize(8)
            doc.setFont('helvetica', 'normal')
            doc.text(`Página ${pageNum}`, 105, doc.internal.pageSize.height - 10, { align: 'center' })
        }

        // Calculate valid disciplines
        const validDisciplines = disciplinas.filter(d => !excludedDisciplines.includes(d.id))

        // Group by period
        const periodoGroups = periodos
            .filter(p => {
                const num = parseInt(p)
                if (isNaN(num)) return true
                if (filterType === 'Impares') return num % 2 !== 0
                if (filterType === 'Pares') return num % 2 === 0
                return true
            })
            .map(periodo => {
                const discs = validDisciplines
                    .filter(d => (d.periodo || 'Optativas') === periodo)
                    .sort((a, b) => a.nome.localeCompare(b.nome))

                return { periodo, disciplinas: discs }
            })
            .filter(g => g.disciplinas.length > 0)

        // FIRST PAGE: Summary by Period
        addHeader('RESUMO POR PERÍODO')

        const summaryByPeriod = periodoGroups.map(group => {
            const totalCH = group.disciplinas.reduce((sum, d) => sum + (d.ch_aula || 0), 0)
            const alocadaCH = group.disciplinas.reduce((sum, d) => {
                const discAlocs = alocacoes.filter(a => a.disciplina_id === d.id)
                return sum + discAlocs.reduce((s, a) => s + (a.ch_alocada || 0), 0)
            }, 0)
            const restanteCH = totalCH - alocadaCH

            return [
                group.periodo === 'Optativas' ? 'Optativas' : `${group.periodo}º Período`,
                `${totalCH}h`,
                `${alocadaCH}h`,
                `${restanteCH}h`,
                `${totalCH > 0 ? Math.round((alocadaCH / totalCH) * 100) : 0}%`
            ]
        })

        // Add totals row
        const globalTotal = summaryByPeriod.reduce((sum, row) => sum + parseInt(row[1]), 0)
        const globalAlocada = summaryByPeriod.reduce((sum, row) => sum + parseInt(row[2]), 0)
        const globalRestante = summaryByPeriod.reduce((sum, row) => sum + parseInt(row[3]), 0)

        summaryByPeriod.push([
            'TOTAL GERAL',
            `${globalTotal}h`,
            `${globalAlocada}h`,
            `${globalRestante}h`,
            `${globalTotal > 0 ? Math.round((globalAlocada / globalTotal) * 100) : 0}%`
        ])

        autoTable(doc, {
            startY: 43,
            head: [['Período', 'CH Total', 'CH Alocada', 'CH Restante', 'Progresso']],
            body: summaryByPeriod,
            styles: { fontSize: 10, cellPadding: 3 },
            headStyles: { fillColor: [0, 51, 102], textColor: 255, fontStyle: 'bold' },
            columnStyles: {
                0: { cellWidth: 50, fontStyle: 'bold' },
                1: { cellWidth: 30, halign: 'center' },
                2: { cellWidth: 30, halign: 'center' },
                3: { cellWidth: 30, halign: 'center' },
                4: { cellWidth: 'auto', halign: 'center' }
            },
            didParseCell: (data) => {
                // Highlight total row
                if (data.row.index === summaryByPeriod.length - 1) {
                    data.cell.styles.fillColor = [255, 215, 0] // Gold
                    data.cell.styles.textColor = 0
                    data.cell.styles.fontStyle = 'bold'
                }
            }
        })

        addFooter()

        // Generate pages per period
        periodoGroups.forEach((group, groupIndex) => {
            doc.addPage()

            addHeader(group.periodo === 'Optativas' ? 'Optativas' : `${group.periodo}º Período`)

            // Helper: Get turno initial
            const getTurnoInitial = (turno: string) => {
                if (!turno || turno === '?') return '?'
                return turno.charAt(0).toUpperCase()
            }

            // Create one row per allocation (not per discipline)
            const tableBody: any[] = []
            const disciplineRowMap: { [key: string]: number[] } = {} // Track which rows belong to each discipline

            group.disciplinas.forEach(d => {
                const discAlocs = alocacoes.filter(a => a.disciplina_id === d.id)
                const startRow = tableBody.length

                if (discAlocs.length === 0) {
                    // Discipline without allocation
                    tableBody.push([
                        d.nome,
                        d.nome_extenso || '-',
                        getTurnoInitial(d.turno || '?'),
                        `${d.ch_aula}h`,
                        'Sem docente',
                        '-'
                    ])
                    disciplineRowMap[d.id] = [startRow]
                } else {
                    // One row per allocation
                    const rows: number[] = []
                    discAlocs.forEach((aloc, index) => {
                        const profName = aloc.professor?.apelido || aloc.professor?.nome || '?'
                        const alocacao = formatDayShift(aloc.dias || [], aloc.slots || [], aloc.turno || 'Manhã')

                        tableBody.push([
                            index === 0 ? d.nome : '', // Show discipline name only on first row
                            index === 0 ? (d.nome_extenso || '-') : '',
                            index === 0 ? getTurnoInitial(d.turno || '?') : '',
                            index === 0 ? `${d.ch_aula}h` : '',
                            `${profName} (${aloc.ch_alocada}h)`,
                            alocacao
                        ])
                        rows.push(tableBody.length - 1)
                    })
                    disciplineRowMap[d.id] = rows
                }
            })

            autoTable(doc, {
                startY: 43,
                head: [['Disciplina', 'Nome Completo', 'Turno', 'CH', 'Docente', 'Alocação']],
                body: tableBody,
                styles: { fontSize: 7, cellPadding: 2 },
                headStyles: { fillColor: [0, 51, 102], textColor: 255, fontStyle: 'bold' }, // UFPB Blue
                columnStyles: {
                    0: { cellWidth: 25 },  // Disciplina (reduzido de 35 para 25)
                    1: { cellWidth: 50 },  // Nome Completo (reduzido de 55 para 50)
                    2: { cellWidth: 12 },  // Turno (reduzido de 15 para 12)
                    3: { cellWidth: 10 },  // CH (reduzido de 12 para 10)
                    4: { cellWidth: 42 },  // Docente (aumentado de 35 para 42)
                    5: { cellWidth: 'auto' } // Alocação (auto = usa espaço restante)
                },
                margin: { top: 43, bottom: 20 },
                // Draw borders around each discipline group
                didDrawCell: (data) => {
                    if (data.section === 'body') {
                        const rowIndex = data.row.index

                        // Find which discipline this row belongs to
                        let isFirstRowOfDisc = false
                        let isLastRowOfDisc = false

                        for (const [discId, rows] of Object.entries(disciplineRowMap)) {
                            if (rows.includes(rowIndex)) {
                                isFirstRowOfDisc = rowIndex === rows[0]
                                isLastRowOfDisc = rowIndex === rows[rows.length - 1]
                                break
                            }
                        }

                        const { doc } = data
                        const { x, y, width, height } = data.cell

                        doc.setDrawColor(100, 100, 100)
                        doc.setLineWidth(0.5)

                        // Draw thicker bottom border for last row of discipline
                        if (isLastRowOfDisc) {
                            doc.line(x, y + height, x + width, y + height)
                        }
                    }
                }
            })

            addFooter()
        })

        // SUMMARY PAGE - All professors with their disciplines
        doc.addPage()
        addHeader('RESUMO GERAL - Docentes e Disciplinas')

        // Build professor summary
        const profSummary: any = {}

        alocacoes.forEach(aloc => {
            const disc = validDisciplines.find(d => d.id === aloc.disciplina_id)
            if (!disc) return

            const profId = aloc.docente_id
            const profName = aloc.professor?.nome || 'Desconhecido'

            if (!profSummary[profId]) {
                profSummary[profId] = {
                    nome: profName,
                    disciplinas: []
                }
            }

            profSummary[profId].disciplinas.push({
                nome: disc.nome,
                ch: aloc.ch_alocada,
                alocacao: formatDayShift(aloc.dias || [], aloc.slots || [], aloc.turno || 'Manhã')
            })
        })

        const summaryBody = Object.values(profSummary)
            .sort((a: any, b: any) => cleanName(a.nome).localeCompare(cleanName(b.nome)))
            .map((prof: any) => {
                const disciplinas = prof.disciplinas
                    .map((d: any) => `${d.nome} (${d.ch}h)`)
                    .join('\n')

                const alocacoes = prof.disciplinas
                    .map((d: any) => d.alocacao)
                    .join('\n')

                const totalCH = prof.disciplinas.reduce((sum: number, d: any) => sum + (d.ch || 0), 0)

                return [
                    prof.nome,
                    disciplinas,
                    alocacoes,
                    `${totalCH}h`
                ]
            })

        autoTable(doc, {
            startY: 43,
            head: [['Docente', 'Disciplinas', 'Alocação', 'CH Total']],
            body: summaryBody,
            styles: {
                fontSize: 8,
                cellPadding: 2,
                lineColor: [200, 200, 200],
                lineWidth: 0.5
            },
            headStyles: { fillColor: [255, 215, 0], textColor: 0, fontStyle: 'bold' }, // Gold
            columnStyles: {
                0: { cellWidth: 45 },  // Docente
                1: { cellWidth: 60 },  // Disciplinas
                2: { cellWidth: 50 },  // Alocação
                3: { cellWidth: 'auto' } // CH Total
            },
            margin: { top: 43, bottom: 20 },
            // Add horizontal lines between rows
            didDrawCell: (data) => {
                // Draw a thicker line after each row (except the last one)
                if (data.section === 'body' && data.column.index === 0) {
                    const isLastRow = data.row.index === summaryBody.length - 1
                    if (!isLastRow) {
                        const { doc } = data
                        const startX = data.settings.margin.left
                        const endX = doc.internal.pageSize.width - data.settings.margin.right
                        const y = data.cell.y + data.cell.height

                        doc.setDrawColor(150, 150, 150)
                        doc.setLineWidth(0.3)
                        doc.line(startX, y, endX, y)
                    }
                }
            }
        })

        addFooter()

        // Save
        const currentSimName = simulacoes.find(s => s.id === activeSimulacaoId)?.nome || 'Simulacao'
        doc.save(`DRI_Relatorio_${semestreId}_${currentSimName.replace(/\s+/g, '_')}.pdf`)
    }

    return (
        <div className="min-h-screen bg-gray-50 flex flex-col font-sans">
            <header className="bg-white border-b border-gray-200 sticky top-0 z-20 shadow-sm print:hidden">
                <div className="max-w-7xl mx-auto px-4 py-3">
                    <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center gap-4">
                            <Link href="/semestre" className="p-2 hover:bg-gray-100 rounded-full text-gray-500">
                                <ArrowLeft size={20} />
                            </Link>
                            <h1 className="text-xl font-bold text-gray-900 flex items-center gap-2 uppercase">
                                <BarChart2 size={20} className="text-indigo-600" />
                                SIMULAÇÃO <span className="text-gray-500 font-normal text-lg ml-1">{semestreLabel || semestreId}</span>
                            </h1>
                        </div>

                        <div className="flex gap-2 items-center">
                            <div className="flex items-center gap-1 bg-white border rounded-lg pl-2 overflow-hidden focus-within:ring-2 focus-within:ring-indigo-500">
                                <select
                                    className="py-1.5 text-sm font-medium text-gray-700 outline-none max-w-[150px]"
                                    value={activeSimulacaoId || ''}
                                    onChange={e => {
                                        if (e.target.value === 'new') {
                                            const nome = prompt("Nome da nova simulação:")
                                            if (nome) createSimulation(nome)
                                        } else {
                                            setActiveSimulacaoId(e.target.value)
                                        }
                                    }}
                                >
                                    {simulacoes.map(s => <option key={s.id} value={s.id}>{s.nome}</option>)}
                                    {userAccessLevel !== 2 && (
                                        <option value="new" className="text-indigo-600 font-bold">+ Nova Simulação</option>
                                    )}
                                </select>
                                {userAccessLevel !== 2 && (
                                    <>
                                        <button
                                            onClick={cloneSimulation}
                                            className="p-2 text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 transition-colors border-l"
                                            title="Clonar Simulação"
                                        >
                                            <Copy size={14} />
                                        </button>
                                        <button
                                            onClick={handleDeleteSimulation}
                                            className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors border-l"
                                            title="Excluir Simulação"
                                            disabled={simulacoes.length <= 1}
                                        >
                                            <Trash2 size={14} />
                                        </button>
                                    </>
                                )}
                            </div>


                            <button
                                onClick={generatePDF}
                                className="flex items-center gap-2 px-3 py-1.5 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors shadow-sm ml-2"
                            >
                                <ArrowLeft size={16} className="rotate-90" /> Exportar PDF
                            </button>

                            <div className="flex bg-gray-100 p-1 rounded-lg ml-2">
                                {(['Todos', 'Impares', 'Pares'] as const).map(type => (
                                    <button
                                        key={type}
                                        onClick={() => setFilterType(type)}
                                        className={clsx("px-3 py-1.5 text-xs font-medium rounded-md transition-all", filterType === type ? "bg-white text-indigo-600 shadow-sm" : "text-gray-500")}
                                    >
                                        {type}
                                    </button>
                                ))}
                            </div>
                        </div>
                    </div>

                    <div className="flex items-center justify-between bg-indigo-50/50 rounded-lg p-3 border border-indigo-100">
                        <div className="flex gap-6 text-sm">
                            <div><span className="text-gray-500 mr-2">Total Previsto:</span><span className="font-bold text-gray-900">{totalCH}h</span></div>
                            <div>
                                <span className="text-gray-500 mr-2">Total Alocado:</span>
                                <span className={clsx("font-bold", allocatedCH >= totalCH ? "text-emerald-600" : "text-indigo-600")}>{allocatedCH}h</span>
                            </div>
                        </div>
                        <div className="flex items-center gap-3 flex-1 max-w-xs ml-4">
                            <div className="flex-1 h-2 bg-gray-200 rounded-full overflow-hidden">
                                <div className="h-full bg-indigo-500 transition-all duration-500" style={{ width: `${Math.min(progress, 100)}%` }}></div>
                            </div>
                            <span className="text-xs font-bold text-indigo-700">{Math.round(progress)}%</span>
                        </div>
                    </div>
                </div>

                <div className="px-4 border-t border-gray-100 bg-white overflow-x-auto">
                    <div className="max-w-7xl mx-auto flex space-x-1 py-1">
                        {visiblePeriodos.map(p => (
                            <button
                                key={p}
                                onClick={() => setActivePeriodo(p)}
                                className={clsx("px-4 py-2 text-sm font-medium whitespace-nowrap border-b-2 transition-colors", activePeriodo === p ? "border-indigo-600 text-indigo-600" : "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-200")}
                            >
                                {p === 'Optativas' ? 'Optativas' : `${p}º Período`}
                            </button>
                        ))}
                    </div>
                </div>
            </header>

            <main className="flex-1 p-6 max-w-7xl mx-auto w-full">
                {loading ? (
                    <div className="flex justify-center py-12"><p className="text-gray-500 animate-pulse">Carregando...</p></div>
                ) : (
                    <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-4 animate-in fade-in duration-300">
                        {activeDisciplines.map((disc: any) => {
                            const discAlocs = alocacoes.filter(a => a.disciplina_id === disc.id)

                            // Define card colors based on shift
                            const isNoite = disc.turno === 'Noite'
                            const isTarde = disc.turno === 'Tarde'
                            const isManha = disc.turno === 'Manhã' || disc.turno === 'Integral'

                            let borderColor = "border-gray-200"
                            let bgColor = "bg-white"

                            if (disc.isIgnored) {
                                borderColor = "border-gray-100"
                                bgColor = "bg-gray-50"
                            } else if (disc.isComplete) {
                                borderColor = "border-emerald-300"
                                bgColor = "bg-emerald-50"
                            } else if (isNoite) {
                                borderColor = "border-indigo-200"
                                bgColor = "bg-indigo-50"
                            } else if (isTarde) {
                                borderColor = "border-amber-200"
                                bgColor = "bg-amber-50"
                            } else if (isManha) {
                                borderColor = "border-orange-200"
                                bgColor = "bg-orange-50"
                            }

                            return (
                                <div key={disc.id} className={clsx(
                                    "rounded-xl border shadow-sm flex flex-col relative group hover:shadow-md transition-all h-full",
                                    bgColor,
                                    borderColor,
                                    disc.isIgnored && "opacity-60 grayscale"
                                )}>
                                    {userAccessLevel !== 2 && (
                                        <button
                                            onClick={(e) => { e.stopPropagation(); toggleDiscipline(disc.id) }}
                                            className="absolute top-2 right-2 p-1 text-gray-300 hover:text-gray-500 z-10"
                                            title={disc.isIgnored ? "Ativar disciplina" : "Ignorar disciplina"}
                                        >
                                            {disc.isIgnored ? <CheckCircle2 size={16} /> : <div className="w-4 h-4 rounded-full border-2 border-gray-300 hover:border-gray-500"></div>}
                                        </button>
                                    )}

                                    <div className="p-4 flex-1 cursor-pointer" onClick={() => { if (userAccessLevel === 2) return; openAllocationModal(disc); }}>
                                        <div className="flex justify-between items-start mb-2 pr-6">
                                            <div className="flex gap-1">
                                                <span className="bg-gray-100 text-gray-600 text-[10px] uppercase font-bold px-1.5 py-0.5 rounded">{disc.ppc || '?'}</span>
                                                <span className={clsx("text-[10px] uppercase font-bold px-1.5 py-0.5 rounded", disc.turno === 'Noite' ? 'bg-indigo-50 text-indigo-700' : 'bg-orange-50 text-orange-700')}>{disc.turno || 'M'}</span>
                                            </div>
                                            {disc.isComplete && !disc.isIgnored && <div className="flex items-center text-white text-[11px] font-black bg-emerald-600 px-2.5 py-1 rounded-full shadow-sm ring-2 ring-emerald-500/20"><CheckCircle2 size={12} className="mr-1" /> OK</div>}
                                            {!disc.isComplete && !disc.isIgnored && <div className="flex items-center text-indigo-600 text-[10px] font-bold bg-indigo-50 px-1.5 py-0.5 rounded-full">{disc.ch_aula}h</div>}
                                        </div>

                                        <h3 className={clsx("font-bold leading-tight mb-1", disc.isIgnored ? "text-gray-400 line-through" : "text-gray-900")} title={disc.nome_extenso}>
                                            {disc.nome}
                                            {discAlocs.length > 0 && (
                                                <span className="text-[#6366f1] font-semibold text-[0.85em]"> - {discAlocs.map(a => a.professor?.apelido || a.professor?.nome).join(', ')}</span>
                                            )}
                                        </h3>
                                        {disc.nome_extenso && disc.nome_extenso !== disc.nome && <p className="text-xs text-gray-400 leading-snug mb-3 line-clamp-2">{disc.nome_extenso}</p>}

                                        {!disc.isIgnored && (
                                            <div className="w-full bg-gray-100 rounded-full h-1.5 my-3 overflow-hidden">
                                                <div className={clsx("h-1.5 rounded-full transition-all duration-500", disc.isComplete ? "bg-emerald-500" : "bg-indigo-500")} style={{ width: `${Math.min((disc.allocated / (disc.ch_aula || 1)) * 100, 100)}%` }}></div>
                                            </div>
                                        )}

                                        <div className="space-y-2">
                                            {discAlocs.map((aloc: any) => (
                                                <div key={aloc.id} className="flex flex-col text-xs bg-gray-50 p-2 rounded border border-gray-100">
                                                    <div className="flex justify-between items-center mb-1">
                                                        <span className="font-medium text-gray-700 truncate w-32" title={aloc.professor?.nome}>{aloc.professor?.apelido || aloc.professor?.nome || 'Prof.'}</span>
                                                    </div>
                                                    <div className="flex justify-between items-center text-gray-500">
                                                        <span>{aloc.ch_alocada}h</span>
                                                        <div className="flex gap-1">
                                                            {(aloc.slots && aloc.slots.length > 0) ? (
                                                                <span className="text-[9px] bg-white border px-1 rounded truncate max-w-[60px]" title={aloc.slots.join(', ')}>{aloc.slots.length} slots</span>
                                                            ) : (aloc.dias || []).map((d: string) => (
                                                                <span key={d} className="bg-white border px-1 rounded text-[9px] uppercase">{d.substring(0, 3)}</span>
                                                            ))}
                                                        </div>
                                                    </div>
                                                </div>
                                            ))}
                                        </div>
                                    </div>

                                    <div className="p-3 border-t border-gray-100 bg-gray-50/50 rounded-b-xl">
                                        {userAccessLevel !== 2 ? (
                                            <button onClick={() => openAllocationModal(disc)} className="w-full py-2 rounded-lg border border-dashed border-gray-300 text-gray-500 text-xs hover:border-indigo-400 hover:text-indigo-600 hover:bg-white transition-all flex items-center justify-center gap-1 font-medium">
                                                {disc.allocated > 0 ? <span className="flex items-center gap-1"><CheckCircle2 size={14} /> Editar Alocação</span> : <span className="flex items-center gap-1"><Plus size={14} /> Alocar Docente</span>}
                                            </button>
                                        ) : (
                                            <div className="w-full py-2 text-gray-400 text-xs text-center italic font-medium">
                                                Visualização Apenas
                                            </div>
                                        )}
                                    </div>
                                </div>
                            )
                        })}
                    </div>
                )}
            </main>

            {isModalOpen && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
                    <div className="bg-white rounded-xl shadow-2xl w-full max-w-3xl max-h-[95vh] overflow-y-auto animate-in zoom-in-95 duration-200 flex flex-col">
                        <div className="p-6 border-b border-gray-100 bg-gray-50 flex justify-between items-start rounded-t-xl">
                            <div>
                                <h3 className="text-xl font-bold text-gray-900">{selectedDisciplina?.nome}</h3>
                                <p className="text-sm text-gray-500 mt-1">{selectedDisciplina?.nome_extenso}</p>
                            </div>
                            <div className="text-right">
                                <span className={clsx("text-xs font-bold px-2 py-1 rounded-full", globalSettings.turno === 'Noite' ? 'bg-indigo-100 text-indigo-700' : 'bg-orange-100 text-orange-700')}>{globalSettings.turno}</span>
                            </div>
                        </div>

                        <div className="p-6 space-y-6 flex-1 overflow-y-auto">
                            <div className="grid grid-cols-2 gap-4 bg-gray-50 p-4 rounded-lg border border-gray-100">
                                <div>
                                    <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-1">Turno Predom.</label>
                                    <select
                                        className="w-full border rounded-lg p-2 bg-white focus:ring-2 focus:ring-indigo-500 outline-none disabled:bg-gray-100"
                                        value={globalSettings.turno}
                                        onChange={e => setGlobalSettings({ ...globalSettings, turno: e.target.value })}
                                        disabled={userAccessLevel === 2}
                                    >
                                        {TURNOS.map(t => <option key={t} value={t}>{t}</option>)}
                                    </select>
                                </div>
                                <div>
                                    <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-1">SALA (Opcional)</label>
                                    <input
                                        type="text"
                                        className="w-full border rounded-lg p-2 bg-white focus:ring-2 focus:ring-indigo-500 outline-none disabled:bg-gray-100"
                                        placeholder="Ex: 101"
                                        value={globalSettings.sala}
                                        onChange={e => setGlobalSettings({ ...globalSettings, sala: e.target.value })}
                                        disabled={userAccessLevel === 2}
                                    />
                                </div>
                            </div>

                            <div>
                                <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Docentes Alocados</label>
                                {allocItems.map((item, index) => (
                                    <div key={item.id} className="flex gap-3 mb-2 items-start">
                                        <div className="flex-1">
                                            <select
                                                className="w-full border rounded-lg p-2.5 bg-white focus:ring-2 focus:ring-indigo-500 outline-none text-sm truncate disabled:bg-gray-100"
                                                value={item.professor}
                                                onChange={e => updateAllocItem(index, 'professor', e.target.value)}
                                                disabled={userAccessLevel === 2}
                                            >
                                                <option value="">Selecione um docente...</option>
                                                {sortedProfessores.map(p => <option key={p.id} value={p.id}>{p.nome}</option>)}
                                            </select>
                                        </div>
                                        <div className="w-24 relative">
                                            <input
                                                type="number"
                                                className="w-full border rounded-lg p-2.5 focus:ring-2 focus:ring-indigo-500 outline-none disabled:bg-gray-100"
                                                value={item.ch}
                                                onChange={e => updateAllocItem(index, 'ch', Number(e.target.value))}
                                                disabled={userAccessLevel === 2}
                                            />
                                            <span className="absolute right-2 top-2.5 text-gray-400 text-xs font-medium">hrs</span>
                                        </div>
                                        {userAccessLevel !== 2 && (
                                            <button onClick={() => removeAllocItem(index)} className="p-2.5 text-red-400 hover:bg-red-50 rounded-lg transition-colors" disabled={allocItems.length === 1}><Trash2 size={18} /></button>
                                        )}
                                    </div>
                                ))}
                                {userAccessLevel !== 2 && (
                                    <button onClick={addAllocItem} className="text-sm text-indigo-600 font-medium hover:text-indigo-800 flex items-center gap-1 mt-2"><Plus size={16} /> Adicionar outro docente</button>
                                )}
                                <div className="mt-2 text-right text-xs text-gray-500 font-medium">Total Alocado desta sessão: {allocItems.reduce((acc, i) => acc + (i.ch || 0), 0)} hrs</div>
                            </div>

                            <hr className="border-gray-100" />

                            <div>
                                <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-3 flex items-center"><Clock size={14} className="mr-1" /> Grade de Horários (Compartilhada)</label>
                                <div className="overflow-x-auto border rounded-xl border-gray-200 shadow-sm">
                                    <table className="w-full text-sm">
                                        <thead>
                                            <tr className="bg-gray-50 text-gray-500 text-xs uppercase border-b border-gray-200">
                                                <th className="py-2 px-3 text-left font-semibold">Horário</th>
                                                {DIAS.map(d => <th key={d} className="py-2 px-1 text-center min-w-[40px]">{d}</th>)}
                                            </tr>
                                        </thead>
                                        <tbody className="divide-y divide-gray-100">
                                            {(SLOTS[globalSettings.turno as keyof typeof SLOTS] || SLOTS['Manhã']).map(slot => (
                                                <tr key={slot} className="hover:bg-gray-50/50">
                                                    <td className="py-2 px-3 font-medium text-gray-600 bg-gray-50/30 border-r border-gray-100 w-16 text-center text-xs">{slot}</td>
                                                    {DIAS.map(dia => {
                                                        const isSelected = globalSettings.slots.includes(`${dia}-${slot}`)
                                                        return (
                                                            <td key={`${dia}-${slot}`} className="p-1 text-center">
                                                                <button
                                                                    onClick={() => { if (userAccessLevel === 2) return; toggleSlot(dia, slot); }}
                                                                    className={clsx(
                                                                        "w-full h-8 rounded-md transition-all border flex items-center justify-center",
                                                                        isSelected ? "bg-indigo-600 border-indigo-600 text-white shadow-sm scale-95" : "bg-white border-gray-200 text-gray-300 hover:border-indigo-300 hover:bg-indigo-50",
                                                                        userAccessLevel === 2 && "cursor-default"
                                                                    )}
                                                                >
                                                                    {isSelected && <CheckCircle2 size={14} />}
                                                                </button>
                                                            </td>
                                                        )
                                                    })}
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>

                        <div className="p-6 border-t border-gray-100 bg-gray-50 rounded-b-xl flex justify-end gap-3">
                            <button onClick={() => setIsModalOpen(false)} className="px-5 py-2.5 text-gray-600 font-medium hover:bg-gray-100 rounded-lg transition-colors">
                                {userAccessLevel === 2 ? 'Fechar' : 'Cancelar'}
                            </button>
                            {userAccessLevel !== 2 && (
                                <button onClick={handleSaveAllocation} className="px-5 py-2.5 bg-indigo-600 text-white font-medium hover:bg-indigo-700 rounded-lg shadow-sm shadow-indigo-200 transition-all transform active:scale-95">Salvar Alocação</button>
                            )}
                        </div>
                    </div>
                </div>
            )}
        </div>
    )
}

export default function SimulacaoPage() {
    return (
        <Suspense fallback={<div>Carregando...</div>}>
            <SimulacaoContent />
        </Suspense>
    )
}
