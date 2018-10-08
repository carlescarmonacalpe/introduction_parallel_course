# Primeros pasos

## Clonar el proyecto
```
git clone https://github.com/carlescarmonacalpe/introduction_parallel_course.git
```

## Compilar el código
```
mkdir bin && cd bin && cmake .. && make
```

# Profiling

### Instalación

```
sudo apt-get install software-properties-common

sudo add-apt-repository ppa:kubuntu-ppa/backports 

sudo apt-get install valgrind kcachegrind graphviz massif-visualizer linux-tools-common
```

### Análisis de performance

#### Profile
```
valgrind --tool=callgrind ./serial_base_debug ../img/small/
```

#### Resultados

```
kcachegrind <filename>
```

#### Preguntas

* ¿Qué diferencias hay entre el profile realizado con el código compilado como debug y el que no?
* ¿Cuáles son las 5 funciones que mas instrucciones ejecutan?
* ¿Qué líneas de código son las más costosas en 3 de las 5 funciones anteriores?
* ¿En que funciones os fijaríais si tuvierais que mejorar la performance de la aplicación?

### IPC / Cycles
```
sudo perf stat ./serial_base_debug ../img/small/
```

#### Preguntas

* ¿Qué diferencias hay entre el profile del serial_base_debug serial_base_debug_O2?
* ¿Por qué el IPC es mayor que 1 si ejecutamos codigo serie?

### Análisis de la memoria cache

#### Profile

```
sudo perf stat -e L1-dcache-loads,L1-dcache-load-misses,L1-dcache-stores,L1-dcache-store-misses ./serial_base_debug ../img/small/
```

```
sudo perf list cache
```

#### Preguntas

* ¿Qué diferencias hay entre L1 y LLC?
* ¿Qué ratios de miss es adecuado?
* ¿Un porcentage menor de miss rate quiere decir menos tiempo de ejecución?
