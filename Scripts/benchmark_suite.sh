#!/bin/bash
# ==============================================================================
# TALLER - COMPARATIVA DE RENDIMIENTO DE 5 ENTORNOS DE ESCRITORIO EN KALI LINUX
# Sistemas Operativos - Universidad Sergio Arboleda
# ==============================================================================

DE_NAME="${1:-UNKNOWN}"
OUTPUT_DIR="/home/kali/benchmarks_data"
mkdir -p "$OUTPUT_DIR"

LOG_FILE="${OUTPUT_DIR}/benchmark_${DE_NAME}.log"
JSON_FILE="${OUTPUT_DIR}/benchmark_${DE_NAME}.json"

STUDENTS="Estudiantes: ANDRÉS SEBASTIÁN CORAL VALLEJO, JUAN ORJUELA, JAVIER ROSERO, ANGEL ARCOS"

export DISPLAY=:0
export XAUTHORITY=/home/kali/.Xauthority

echo "$STUDENTS" | tee "$LOG_FILE"
echo "================================================================================" | tee -a "$LOG_FILE"
echo ">>> INICIANDO BENCHMARK PARA EL ENTORNO: $DE_NAME" | tee -a "$LOG_FILE"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "================================================================================" | tee -a "$LOG_FILE"

# 1. Medición de recursos en reposo (idle)
sleep 2
RAM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
RAM_USED=$(free -m | awk '/^Mem:/{print $3}')
RAM_FREE=$(free -m | awk '/^Mem:/{print $4}')
RAM_AVAIL=$(free -m | awk '/^Mem:/{print $7}')
SWAP_USED=$(free -m | awk '/^Swap:/{print $3}')
PROC_COUNT=$(ps -ef --no-headers | wc -l)
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

echo "" | tee -a "$LOG_FILE"
echo "--- [1] ESTADO DEL SISTEMA EN REPOSO ---" | tee -a "$LOG_FILE"
echo "Memoria Total:       ${RAM_TOTAL} MB" | tee -a "$LOG_FILE"
echo "Memoria Usada:       ${RAM_USED} MB" | tee -a "$LOG_FILE"
echo "Memoria Libre:       ${RAM_FREE} MB" | tee -a "$LOG_FILE"
echo "Memoria Disponible:  ${RAM_AVAIL} MB" | tee -a "$LOG_FILE"
echo "Swap Usado:          ${SWAP_USED} MB" | tee -a "$LOG_FILE"
echo "Procesos Activos:    ${PROC_COUNT}" | tee -a "$LOG_FILE"
echo "Carga Media (1,5,15m): ${LOAD_AVG}" | tee -a "$LOG_FILE"

# 2. Información del Entorno con Fastfetch
echo "" | tee -a "$LOG_FILE"
echo "--- [2] INFORMACIÓN DEL ENTORNO DE ESCRITORIO (FASTFETCH) ---" | tee -a "$LOG_FILE"
fastfetch 2>&1 | tee -a "$LOG_FILE"

# 3. Benchmark de CPU con Sysbench
echo "" | tee -a "$LOG_FILE"
echo "--- [3] BENCHMARK DE CPU (SYSBENCH PRIMES 20000 - 2 THREADS) ---" | tee -a "$LOG_FILE"
CPU_RAW=$(sysbench cpu --cpu-max-prime=20000 --threads=2 run 2>&1)
echo "$CPU_RAW" | tee -a "$LOG_FILE"

CPU_EVENTS_PER_SEC=$(echo "$CPU_RAW" | grep "events per second:" | awk '{print $4}')
CPU_TOTAL_TIME=$(echo "$CPU_RAW" | grep "total time:" | awk '{print $3}' | tr -d 's')
CPU_LATENCY_MIN=$(echo "$CPU_RAW" | grep "min:" | awk '{print $2}')
CPU_LATENCY_AVG=$(echo "$CPU_RAW" | grep "avg:" | awk '{print $2}')
CPU_LATENCY_MAX=$(echo "$CPU_RAW" | grep "max:" | awk '{print $2}')
CPU_LATENCY_95=$(echo "$CPU_RAW" | grep "95th percentile:" | awk '{print $3}')

# 4. Información de Aceleración Gráfica (OpenGL)
echo "" | tee -a "$LOG_FILE"
echo "--- [4] INFORMACIÓN DE ACELERACIÓN GRÁFICA (MESA OPENGL) ---" | tee -a "$LOG_FILE"
GLX_RAW=$(glxinfo -B 2>&1)
echo "$GLX_RAW" | tee -a "$LOG_FILE"

GL_RENDERER=$(echo "$GLX_RAW" | grep "OpenGL renderer string:" | cut -d':' -f2 | xargs)
GL_VENDOR=$(echo "$GLX_RAW" | grep "OpenGL vendor string:" | cut -d':' -f2 | xargs)
GL_VERSION=$(echo "$GLX_RAW" | grep "OpenGL core profile version string:" | cut -d':' -f2 | xargs)
if [ -z "$GL_VERSION" ]; then
    GL_VERSION=$(echo "$GLX_RAW" | grep "OpenGL version string:" | cut -d':' -f2 | xargs)
fi

# 5. Benchmark de GPU con glmark2
echo "" | tee -a "$LOG_FILE"
echo "--- [5] BENCHMARK DE GPU (GLMARK2 SCENES: BUILD, TEXTURE, TERRAIN) ---" | tee -a "$LOG_FILE"
GPU_RAW=$(glmark2 --benchmark build:duration=2.5 --benchmark texture:duration=2.5 --benchmark terrain:duration=2.5 2>&1)
echo "$GPU_RAW" | tee -a "$LOG_FILE"

GLMARK_SCORE=$(echo "$GPU_RAW" | grep "glmark2 Score:" | awk '{print $3}')
if [ -z "$GLMARK_SCORE" ]; then
    GLMARK_SCORE="0"
fi

BUILD_FPS=$(echo "$GPU_RAW" | grep "\[build\]" | grep "FPS:" | awk '{print $4}')
TEXTURE_FPS=$(echo "$GPU_RAW" | grep "\[texture\]" | grep "FPS:" | awk '{print $4}')
TERRAIN_FPS=$(echo "$GPU_RAW" | grep "\[terrain\]" | grep "FPS:" | awk '{print $4}')

FPS_SUM=0
FPS_COUNT=0
for f in $BUILD_FPS $TEXTURE_FPS $TERRAIN_FPS; do
    if [ ! -z "$f" ]; then
        FPS_SUM=$(awk "BEGIN {print $FPS_SUM + $f}")
        FPS_COUNT=$((FPS_COUNT + 1))
    fi
done

if [ "$FPS_COUNT" -gt 0 ]; then
    AVG_FPS=$(awk "BEGIN {printf \"%.2f\", $FPS_SUM / $FPS_COUNT}")
else
    AVG_FPS="0"
fi

# Guardar métricas en JSON estructurado
cat <<EOF > "$JSON_FILE"
{
  "desktop_environment": "$DE_NAME",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "ram_total_mb": ${RAM_TOTAL:-0},
  "ram_used_mb": ${RAM_USED:-0},
  "ram_free_mb": ${RAM_FREE:-0},
  "ram_avail_mb": ${RAM_AVAIL:-0},
  "swap_used_mb": ${SWAP_USED:-0},
  "process_count": ${PROC_COUNT:-0},
  "load_avg": "$LOAD_AVG",
  "cpu_benchmark": {
    "tool": "sysbench cpu",
    "params": "max-prime=20000 threads=2",
    "events_per_sec": ${CPU_EVENTS_PER_SEC:-0},
    "total_time_sec": ${CPU_TOTAL_TIME:-0},
    "latency_min_ms": ${CPU_LATENCY_MIN:-0},
    "latency_avg_ms": ${CPU_LATENCY_AVG:-0},
    "latency_max_ms": ${CPU_LATENCY_MAX:-0},
    "latency_95_ms": ${CPU_LATENCY_95:-0}
  },
  "gpu_benchmark": {
    "tool": "glmark2",
    "renderer": "$GL_RENDERER",
    "vendor": "$GL_VENDOR",
    "opengl_version": "$GL_VERSION",
    "glmark2_score": ${GLMARK_SCORE:-0},
    "avg_fps": ${AVG_FPS:-0},
    "scenes": {
      "build_fps": "${BUILD_FPS:-0}",
      "texture_fps": "${TEXTURE_FPS:-0}",
      "terrain_fps": "${TERRAIN_FPS:-0}"
    }
  }
}
EOF

echo "" | tee -a "$LOG_FILE"
echo "================================================================================" | tee -a "$LOG_FILE"
echo ">>> BENCHMARK COMPLETADO EXITOSAMENTE PARA: $DE_NAME" | tee -a "$LOG_FILE"
echo "Puntaje Glmark2: $GLMARK_SCORE | FPS Promedio: $AVG_FPS | Sysbench Events/s: $CPU_EVENTS_PER_SEC | RAM Usada: ${RAM_USED} MB" | tee -a "$LOG_FILE"
echo "$STUDENTS" | tee -a "$LOG_FILE"
echo "================================================================================" | tee -a "$LOG_FILE"
