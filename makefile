# Makefile para pruebas de Talpiko Framework

test: test-unit test-integration

test-unit:
	nim c -r tests/backend/core/logging_test.nim
	nim c -r tests/backend/core/types_test.nim
	nim c -r tests/backend/core/di/container_test.nim

test-integration:
	nim c -r tests/backend/integration/core_integration_test.nim

test-all: test-unit test-integration

clean:
	rm -f tests/backend/core/*.o
	rm -f tests/backend/core/di/*.o
	rm -f tests/backend/integration/*.o
	rm -f test.log