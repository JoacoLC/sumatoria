# **SUMATORIA**

### **Un juego arcade de puzzles sobre llegar a cero**

#### **Por Joaquín Labanda**

#### **CC-BY-NC-SA 2026**



##### OBJETIVOS Y FILOSOFÍA DE DISEÑO

* Reglas inmediatamente simples de entender.
* Profundidad estratégica, viabilidad competitiva al jugar por puntuación.
* Filosofía arcade en el sentido más puro. El jugador promedio (sin experiencia) debería durar \~3min antes de perder y a la vez tener una experiencia divertida, interesante y significativa.
* Requerimientos mínimos:

&#x09;Procesador \[...] (\[...]Mhz, mononúcleo, \[...] L1 cache, \[...] L2 cache) o mejor

&#x09;32KB de almacenamiento libre

&#x09;16MB de RAM

&#x09;Resolución 640x480, tarjeta gráfica con soporte para OpenGL 2.0 o superior

* La obsolescencia es una ilusión



##### TODO

* ~~Piezas que caigan automáticamente~~
* ~~Rotación de piezas (y consecuentes cambios en la detección de colisión)~~
* ~~Curva de dificultad~~
* ~~Mejor detección de suma/resta~~
* ~~Stack que crece cada 15 niveles~~
* ~~Combos~~
* ~~Texto, pantallas de título y game over~~
* ~~Animación de operación~~
* ~~Efectos de sonido~~
* ~~Música~~
* ~~Animación de explosión + efecto de sonido al eliminar un bloque~~
* ~~Cambiar detección de colisión en las rotaciones~~
* ~~Que puedan ocurrir dos operaciones en simultáneo~~
* ~~Mejorar randomización + piece preview~~
* ~~Opciones de control~~
* Solucionar bug por el cual no cargan los gráficos en PCs más viejas (hay que cargar a cada cacho de 32x32 de la spritesheet como una textura distinta)
* Cambiar GetMessage por PeekMessage (de otro modo, se puede stallear el juego machacando cualquier input o moviendo el mouse)
* Optimizar tiempos de carga (enteramente dependiente de la música y el sonido, tendría que aprender a usar su\_render de sointu)
* Optimizar input lag en PC de la Casita
* Soporte para mando
* Guardado de puntuación
* Pantalla de título más bonita
* Fondo piola
* Tutorial
* Números de colores que salen disparados y muestran cuántos puntos y combos hiciste al eliminar un bloque
* Render batching
* Optimización de RAM (probablemente mejore al mismo tiempo que los tiempos de carga de la música, aunque cambiar el modo de color a 8bit palettized tampoco vendría mal)
* Optimización de tamaño
* Resolución adaptativa (basada en la resolución de la computadora) y spritesheet a distintas resoluciones
* Multijugador



###### RELEASE 1.0



* Build de 32 bits



##### OPTIMIZACIÓN DE TAMAÑO



Meta de tamaño: 32KB



*(Los números a continuación son aproximados)*



La spritesheet agrega 8KB

La animación de explosión agregó 2KB

Lodepng agregó cerca de 100KB (gran parte debe ser la librería estándar de C, probar sacando eso primero)

Opciones de control agregaron 1KB

Cambiar la rotación por flippeo quitó 1KB

Archivo de recursos sumatoria.rc con el ícono agregó 4KB

~~-DLODEPNG\_NO\_COMPILE\_ZLIB quitó 8KB~~ (la imagen no carga sin esto)

\-DLODEPNG\_NO\_COMPILE\_ENCODER quitó 17KB

\-DLODEPNG\_NO\_COMPILE\_ERROR\_TEXT quitó 7KB



##### OPTIMIZACIÓN DE RAM



*(Los números a continuación son aproximados)*



La música en Sointu agregó 80MB (se van sumando progresivamente)

Gráficos agregaron 13MB



TERMINADO PARA EL 28/11 O ANTES

