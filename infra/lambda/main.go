package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ses"
)

var (
	MessageNotProvided = errors.New("no message provided")
	SenderNotProvided  = errors.New("no sender provided")
	ChainNotProvided   = errors.New("no chain provided")
	Unauthorized       = errors.New("unauthorized")
)

const (
	Success = "success"
	Error   = "error"
)

var (
	toEmail     string
	subject     string
	authSecret  string
	emailClient *ses.SES

	chainToName = map[string]string{
		"5":     "Ethereum Goerli",
		"80001": "Polygon Mumbai",
	}
)

type ResponseMessage struct {
	Type    string `json:"type"`
	Message string `json:"message,omitempty"`
}

func init() {
	toEmail = os.Getenv("TO_EMAIL")
	subject = os.Getenv("SUBJECT")
	authSecret = os.Getenv("SECRET")

	if len(subject) < 0 {
		subject = "NerifBridge: message received"
	}

	emailClient = ses.New(session.Must(session.NewSession()))
}

func Failed(err error, status int) (events.APIGatewayProxyResponse, error) {
	errorMessage, _ := json.Marshal(ResponseMessage{
		Type:    Error,
		Message: err.Error(),
	})

	return events.APIGatewayProxyResponse{
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		StatusCode: status,
		Body:       string(errorMessage),
	}, nil
}

func Handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	if authSecret != "" {
		secret := request.Headers["x-nerifbridge-secret"]
		if secret != authSecret {
			return Failed(Unauthorized, http.StatusUnauthorized)
		}
	}

	message := request.Headers["x-nerifbridge-message"]
	if message == "" {
		return Failed(MessageNotProvided, http.StatusBadRequest)
	}

	sender := request.Headers["x-nerifbridge-sender"]
	if sender == "" {
		return Failed(SenderNotProvided, http.StatusBadRequest)
	}

	chain := request.Headers["x-nerifbridge-chain"]
	if chain == "" {
		return Failed(ChainNotProvided, http.StatusBadRequest)
	}

	emailParams := &ses.SendEmailInput{
		Message: &ses.Message{
			Body: &ses.Body{
				Text: &ses.Content{
					Data: aws.String(fmt.Sprintf("Received message from %s (%s): %s", sender, chainToName[chain], message)),
				},
			},
			Subject: &ses.Content{
				Data: aws.String(subject),
			},
		},
		Destination: &ses.Destination{
			ToAddresses: []*string{aws.String(toEmail)},
		},
		Source: aws.String(toEmail),
	}

	if _, err := emailClient.SendEmail(emailParams); err != nil {
		return Failed(err, http.StatusInternalServerError)
	}

	successResponse, err := json.Marshal(ResponseMessage{
		Type: Success,
	})
	if err != nil {
		return Failed(err, http.StatusInternalServerError)
	}

	return events.APIGatewayProxyResponse{
		Body:       string(successResponse),
		StatusCode: http.StatusOK,
	}, nil

}

func main() {
	lambda.Start(Handler)
}
