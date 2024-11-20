#!/bin/bash

# Путь к файлу схемы Circom
CIRCUIT_NAME="circom/product"

DATA_DIR="data"

PTAU_FIRST_FILE="${DATA_DIR}/keys/pot12_0000.ptau"
PTAU_SECOND_FILE="${DATA_DIR}/keys/pot12_0001.ptau"
PTAU_FINAL_FILE="${DATA_DIR}/keys/pot12_final.ptau"

ZKEY_FIRST_FILE="${DATA_DIR}/keys/product_0000.zkey"
ZKEY_SECOND_FILE="${DATA_DIR}/keys/product_0001.zkey"
VERIFICATION_KEY_FILE="${DATA_DIR}/keys/verification_key.json"

WITNESS_FILE="${DATA_DIR}/witnesses/witness.wtns"

INPUT_FILE="${DATA_DIR}/proof_data/input.json"
PROOF_FILE="${DATA_DIR}/proof_data/proof.json"
PUBLIC_FILE="${DATA_DIR}/proof_data/public.json"

COMPILED_DIR="${DATA_DIR}/compiled"

PRODUCT_JS_DIR="${DATA_DIR}/product_js"

CONTRACTS_DIR="contracts"
VERIFIER_SOL_FILE="contracts/verifier"

# Создание папок для организации файлов
mkdir -p ${DATA_DIR}/keys ${DATA_DIR}/proof_data ${DATA_DIR}/witnesses ${COMPILED_DIR} ${PRODUCT_JS_DIR}
mkdir ${CONTRACTS_DIR}

#### Первая фаза
# 1. Компиляция схемы Circom
echo "Компиляция схемы Circom..."
circom ${CIRCUIT_NAME}.circom --r1cs --wasm --sym -o ${COMPILED_DIR} --c

# Перемещение скомпилированных файлов в соответствующие папки
mv ${COMPILED_DIR}/product_js/* ${PRODUCT_JS_DIR} 2>/dev/null || true

# 2. Генерация входных данных (input.json)
echo "Создание файла входных данных..."
cat > ${INPUT_FILE} <<EOL
{
    "a": "1",
    "b": "2",
    "c": "1",
    "x": "-1"
}
EOL

# 3. Вычисление witness с использованием WebAssembly
echo "Вычисление witness..."
node ${PRODUCT_JS_DIR}/generate_witness.js ${PRODUCT_JS_DIR}/product.wasm ${INPUT_FILE} ${WITNESS_FILE}
echo "Файл witness.wtns создан и сохранен в ${DATA_DIR}/witnesses."

# 4. Создание файла Powers of Tau (ptau), если он еще не создан
if [ ! -f PTAU_FIRST_FILE ]; then
    echo "Загрузка файла Powers of Tau..."
    snarkjs powersoftau new bn128 12 ${PTAU_FIRST_FILE} -v
    snarkjs powersoftau contribute ${PTAU_FIRST_FILE} ${PTAU_SECOND_FILE} --name="Первый ptau взнос" -v
fi

#### Вторая фаза
#### Подготовка
mkdir -p ${DATA_DIR}/keys ${DATA_DIR}/proof_data ${DATA_DIR}/witnesses ${COMPILED_DIR} ${PRODUCT_JS_DIR}
if [ ! -f "${PTAU_FIRST_FILE}" ]; then
  echo "Файл ${PTAU_FIRST_FILE} не найден!"
  exit 1
fi
if [ ! -f "${PTAU_SECOND_FILE}" ]; then
  echo "Файл ${PTAU_SECOND_FILE} не найден!"
  exit 1
fi
if [ ! -f "${COMPILED_DIR}/product.r1cs" ]; then
  echo "Файл ${COMPILED_DIR}/product.r1cs не найден! Пожалуйста, выполните компиляцию схемы."
  exit 1
fi

# 1. Вторая фаза зависит от схемы
echo "Подготовка схемы..."
snarkjs powersoftau prepare phase2 ${PTAU_SECOND_FILE} ${PTAU_FINAL_FILE} -v
# 2. Генерация ключей
echo "Настройка Groth16..."
snarkjs groth16 setup ${COMPILED_DIR}/product.r1cs ${PTAU_FINAL_FILE} ${ZKEY_FIRST_FILE}
# 3. Проведение церемонии
echo "Церемония второй фазы..."
snarkjs zkey contribute ${ZKEY_FIRST_FILE} ${ZKEY_SECOND_FILE} --name="Первый zkey взнос" -v
# 4. Экспорт ключа
echo "Экспортирование ключа..."
snarkjs zkey export verificationkey ${ZKEY_SECOND_FILE} ${VERIFICATION_KEY_FILE}


#### Третья фаза
# 1. Генерация доказательства
echo "Генерация доказательства..."
snarkjs groth16 prove ${ZKEY_SECOND_FILE} ${WITNESS_FILE} ${PROOF_FILE} ${PUBLIC_FILE}


#### Четвертая фаза
# 1. Проверка доказательства
echo "Проверка доказательства..."
snarkjs groth16 verify ${VERIFICATION_KEY_FILE} ${PUBLIC_FILE} ${PROOF_FILE}


#### Проверка со стороны умного контракта
echo "Экспорт умного контракта..."
snarkjs zkey export solidityverifier ${ZKEY_SECOND_FILE} ${VERIFIER_SOL_FILE}.sol

echo "Генерация вызова"
snarkjs generatecall --public ${PUBLIC_FILE} --proof ${PROOF_FILE}