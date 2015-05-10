#include <stdio.h>
#include <stdlib.h>

#define BLOCK_SIZE					8
#define LINE_SIZE					(BLOCK_SIZE * 4)
#define PAGE_SIZE					1024

#define PAGE_HEADER	\
   "--%7ldK:  0  1  2  3  4  5  6  7   8  9 10 11 12 13 14 15  16 17 18 19 20 21 22 23  24 25 26 27 28 29 30 31 : 0       8      16      24\n" \
"----------++-----------------------++-----------------------++-----------------------++-----------------------++-+-------+-------+-------+-------\n"
#define PAGE_FOOTER					"\n"

#define LINE_HEADER					"%010ld: "
#define LINE_FOOTER					":%s\n"

#define BLOCK_SEPARATOR			" "

/* 16進数表示用配列 */
const char xpcHexChr[] = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};

/* １６進ダンプファイル出力処理 */
static void hex_dump_to_fp(
	char *pcStr,
	long iStrLen,
	FILE *pFp
);

void HexDumpToFile(
	char *pcStr,
	long iStrLen,
	char *pcFilePath
)
{
	FILE *pFp = NULL;				/* ファイルポインタ */

	pFp = fopen(pcFilePath,"w");
	hex_dump_to_fp(pcStr, iStrLen, pFp);
	fclose(pFp);
}

void HexDumpToStdout(
	char *pcStr,
	long iStrLen
)
{
	hex_dump_to_fp(pcStr, iStrLen, stdout);
}

static void hex_dump_to_fp(
	char *pcStr,
	long iStrLen,
	FILE *pFp
)
{

	long iAddress = 0;										/* 出力中のアドレス							*/
	unsigned char bChr = '\0';						/* 出力中の文字									*/
	char pcBinStr[LINE_SIZE + 1];					/* バイナリ出力バッファ					*/

	long iOutLen = 0;											/* 行末までの出力サイズ					*/

	/* １バイトずつ処理する */
	for (iAddress = 0; iAddress < iStrLen; ) {

		/* ページ先頭位置の場合 */
		if ((iAddress % PAGE_SIZE) == 0) {
			/* ページ見出しを出力 */
			fprintf(pFp, PAGE_HEADER, iAddress / PAGE_SIZE);
		}

		/* 行頭の場合 */
		if ((iAddress % LINE_SIZE) == 0) {
			/* 行見出しを出力 */
			fprintf(pFp, LINE_HEADER, iAddress);
			/* バイナリ出力バッファを初期化 */
			memset(pcBinStr, '\0', sizeof(pcBinStr));
		}

		/* 現在位置の文字を取得 */
		bChr = *(pcStr+ iAddress);

		/* 文字の16進表記を出力 */
		fprintf(pFp,"%c%c ", xpcHexChr[bChr >> 4], xpcHexChr[bChr & 15]);

		/* バイナリ出力バッファに出力 */
		if (bChr < 0x20
			|| bChr == 0x7f
			|| bChr > 0xfc
		) {
			/* 制御コードはバイナリ表示を中黒に置き換え */
			pcBinStr[iAddress % LINE_SIZE] = '･';
		} else {
			/* 上記以外はそのまま出力 */
			pcBinStr[iAddress % LINE_SIZE] = bChr;
		}

		/* アドレスをインクリメント */
		iAddress++;

		/* ブロック終了位置の場合 */
		if ((iAddress % BLOCK_SIZE) == 0) {
			/* ブロック区切りを出力 */
			fprintf(pFp, BLOCK_SEPARATOR);
		}

		/* 行末の場合 */
		if ((iAddress % LINE_SIZE) == 0) {
			/* バイナリ出力バッファの内容を行フッタとして出力 */
			fprintf(pFp, LINE_FOOTER, pcBinStr);
		}

		/* ページ終了位置の場合 */
		if ((iAddress % PAGE_SIZE) == 0) {
			/* ページフッタを出力 */
			fprintf(pFp, PAGE_FOOTER);
		}

	}

	/* 行末の位置を求める */
	iOutLen = ((iStrLen + (LINE_SIZE -1)) / LINE_SIZE) * LINE_SIZE;

	/* 行末までさらに処理する */
	for (; iAddress < iOutLen; ) {

		/* １６進ダンプをスペースで埋める */
		fprintf(pFp, "   ");

		/* アドレスをインクリメント */
		iAddress++;

		/* ブロック終了位置の場合 */
		if ((iAddress % BLOCK_SIZE) == 0) {
			/* ブロック区切りを出力 */
			fprintf(pFp, BLOCK_SEPARATOR);
		}

		/* 行末の場合 */
		if ((iAddress % LINE_SIZE) == 0) {
			/* バイナリ出力バッファの内容を行フッタとして出力 */
			fprintf(pFp, LINE_FOOTER, pcBinStr);
		}

		/* ページ終了位置の場合 */
		if ((iAddress % PAGE_SIZE) == 0) {
			/* ページフッタを出力 */
			fprintf(pFp, PAGE_FOOTER);
		}

	}

	/* ファイルをフラッシュ */
	fflush(pFp);
}

