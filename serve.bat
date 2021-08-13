@IF EXIST node_modules GOTO town
@echo First Time Setup.
@npm install
@md db
:town
@node --unhandled-rejections=strict app.js
@IF %ERRORLEVEL% EQU 99 (
	@GOTO town
)
