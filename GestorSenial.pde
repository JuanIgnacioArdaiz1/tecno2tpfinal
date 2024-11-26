int altoGestor = 50;
int anchoGestor = 200;

class GestorSenial {
  float minimo, maximo;
  int puntero = 0;
  int cargado = 0;
  float[] mapeada = new float[anchoGestor];
  float filtrada = 0;
  float anterior = 0;
  float derivada = 0;
  float[] histFiltrada = new float[anchoGestor];
  float[] histDerivada = new float[anchoGestor];
  float amplificadorDerivada = 15.0;
  boolean dibujarDerivada = false;
  float f = 0.80;

  GestorSenial(float minimo_, float maximo_) {
    minimo = minimo_;
    maximo = maximo_;
  }

  void actualizar(float entrada) {
    mapeada[puntero] = map(entrada, minimo, maximo, 0.0, 1.0);
    mapeada[puntero] = constrain(mapeada[puntero], 0.0, 1.0);

    filtrada = filtrada * f + mapeada[puntero] * (1 - f);
    histFiltrada[puntero] = filtrada;

    derivada = (filtrada - anterior) * amplificadorDerivada;
    histDerivada[puntero] = derivada;

    anterior = filtrada;

    puntero++;
    if (puntero >= anchoGestor) {
      puntero = 0;
    }
    cargado = max(cargado, puntero);
  }

  void dibujar(int x, int y) {
    pushMatrix();
    fill(0);
    stroke(255);
    rect(x, y, anchoGestor, altoGestor);

    for (int i = 1; i < cargado; i++) {
      float altura1 = map(mapeada[i - 1], 0.0, 1.0, y + altoGestor, y);
      float altura2 = map(mapeada[i], 0.0, 1.0, y + altoGestor, y);

      stroke(25);
      line(x + i - 1, altura1, x + i, altura2);

      altura1 = map(histFiltrada[i - 1], 0.0, 1.0, y + altoGestor, y);
      altura2 = map(histFiltrada[i], 0.0, 1.0, y + altoGestor, y);

      stroke(255);
      line(x + i - 1, altura1, x + i, altura2);

      if (dibujarDerivada) {
        altura1 = map(histDerivada[i - 1], -1.0, 1.0, y + altoGestor, y);
        altura2 = map(histDerivada[i], -1.0, 1.0, y + altoGestor, y);

        stroke(255, 255, 0);
        line(x + i - 1, altura1, x + i, altura2);
      }
    }
    stroke(255, 0, 0);
    line(x + puntero, y, x + puntero, y + altoGestor);
    popMatrix();
  }
}
