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

/* 16�i���\���p�z�� */
const char xpcHexChr[] = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};

/* �P�U�i�_���v�t�@�C���o�͏��� */
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
	FILE *pFp = NULL;				/* �t�@�C���|�C���^ */

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

	long iAddress = 0;										/* �o�͒��̃A�h���X							*/
	unsigned char bChr = '\0';						/* �o�͒��̕���									*/
	char pcBinStr[LINE_SIZE + 1];					/* �o�C�i���o�̓o�b�t�@					*/

	long iOutLen = 0;											/* �s���܂ł̏o�̓T�C�Y					*/

	/* �P�o�C�g���������� */
	for (iAddress = 0; iAddress < iStrLen; ) {

		/* �y�[�W�擪�ʒu�̏ꍇ */
		if ((iAddress % PAGE_SIZE) == 0) {
			/* �y�[�W���o�����o�� */
			fprintf(pFp, PAGE_HEADER, iAddress / PAGE_SIZE);
		}

		/* �s���̏ꍇ */
		if ((iAddress % LINE_SIZE) == 0) {
			/* �s���o�����o�� */
			fprintf(pFp, LINE_HEADER, iAddress);
			/* �o�C�i���o�̓o�b�t�@�������� */
			memset(pcBinStr, '\0', sizeof(pcBinStr));
		}

		/* ���݈ʒu�̕������擾 */
		bChr = *(pcStr+ iAddress);

		/* ������16�i�\�L���o�� */
		fprintf(pFp,"%c%c ", xpcHexChr[bChr >> 4], xpcHexChr[bChr & 15]);

		/* �o�C�i���o�̓o�b�t�@�ɏo�� */
		if (bChr < 0x20
			|| bChr == 0x7f
			|| bChr > 0xfc
		) {
			/* ����R�[�h�̓o�C�i���\���𒆍��ɒu������ */
			pcBinStr[iAddress % LINE_SIZE] = '�';
		} else {
			/* ��L�ȊO�͂��̂܂܏o�� */
			pcBinStr[iAddress % LINE_SIZE] = bChr;
		}

		/* �A�h���X���C���N�������g */
		iAddress++;

		/* �u���b�N�I���ʒu�̏ꍇ */
		if ((iAddress % BLOCK_SIZE) == 0) {
			/* �u���b�N��؂���o�� */
			fprintf(pFp, BLOCK_SEPARATOR);
		}

		/* �s���̏ꍇ */
		if ((iAddress % LINE_SIZE) == 0) {
			/* �o�C�i���o�̓o�b�t�@�̓��e���s�t�b�^�Ƃ��ďo�� */
			fprintf(pFp, LINE_FOOTER, pcBinStr);
		}

		/* �y�[�W�I���ʒu�̏ꍇ */
		if ((iAddress % PAGE_SIZE) == 0) {
			/* �y�[�W�t�b�^���o�� */
			fprintf(pFp, PAGE_FOOTER);
		}

	}

	/* �s���̈ʒu�����߂� */
	iOutLen = ((iStrLen + (LINE_SIZE -1)) / LINE_SIZE) * LINE_SIZE;

	/* �s���܂ł���ɏ������� */
	for (; iAddress < iOutLen; ) {

		/* �P�U�i�_���v���X�y�[�X�Ŗ��߂� */
		fprintf(pFp, "   ");

		/* �A�h���X���C���N�������g */
		iAddress++;

		/* �u���b�N�I���ʒu�̏ꍇ */
		if ((iAddress % BLOCK_SIZE) == 0) {
			/* �u���b�N��؂���o�� */
			fprintf(pFp, BLOCK_SEPARATOR);
		}

		/* �s���̏ꍇ */
		if ((iAddress % LINE_SIZE) == 0) {
			/* �o�C�i���o�̓o�b�t�@�̓��e���s�t�b�^�Ƃ��ďo�� */
			fprintf(pFp, LINE_FOOTER, pcBinStr);
		}

		/* �y�[�W�I���ʒu�̏ꍇ */
		if ((iAddress % PAGE_SIZE) == 0) {
			/* �y�[�W�t�b�^���o�� */
			fprintf(pFp, PAGE_FOOTER);
		}

	}

	/* �t�@�C�����t���b�V�� */
	fflush(pFp);
}

